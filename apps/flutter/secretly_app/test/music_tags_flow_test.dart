// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/app/message_command_utils.dart';
import 'package:secretly_app/app/pending_attachment_upload.dart';
import 'package:secretly_app/crypto/dart_crypto_provider.dart';
import 'package:secretly_app/media/music_tags.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/ui/desktop/app/desktop_media_send.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/chat/outgoing_media.dart';
import 'package:secretly_app/ui/desktop/chat/send_media_dialog.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

// 🔴 НАЗВАНИЕ И ИСПОЛНИТЕЛЬ ПЕСНИ — ВЕСЬ ПУТЬ (17.09.2026, указание владельца:
// «исправь то что нашёл по поводу музыки, проверь и обычные чаты»).
//
// Что было сломано:
//   • очередь телефона стартует сразу и забирала подписи раньше, чем теги
//     успевали прочитаться, — песня уходила с именем файла и без исполнителя;
//   • на iPhone теги не читались вовсе (библиотека отключена);
//   • голосовое (`audio/mp4`, как музыка) считалось песней;
//   • копия «на свои устройства» теряла теги и волну голосового;
//   • в комнатах теги не доезжали до участников;
//   • компьютер и пересылка теги не передавали;
//   • имя файла, выданное за название, заслоняло настоящие теги.

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
const _musicTagsChannel = MethodChannel('secretly/music_tags');

AttachmentEventV1 _att({
  String? musicTitle,
  String? musicArtist,
  String? filename,
  String mime = 'audio/mpeg',
  List<int>? waveform,
}) => AttachmentEventV1(
  eventId: 'e1',
  blobId: 'b1',
  fileKeyB64: 'k',
  sizeBytes: 10,
  mime: mime,
  musicTitle: musicTitle,
  musicArtist: musicArtist,
  filename: filename,
  waveform: waveform,
);

Future<void> _until(bool Function() cond, {int tries = 600}) async {
  for (var i = 0; i < tries && !cond(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(cond(), isTrue);
}

class _Owner {
  _Owner(this.db, this.crypto, this.controller);

  final AppDb db;
  final DartCryptoProvider crypto;
  final AppController controller;

  static Future<_Owner> open() async {
    final db = await AppDb.openForTesting();
    addTearDown(db.close);
    final crypto = DartCryptoProvider(
      Uint8List.fromList(List<int>.generate(32, (i) => i)),
    );
    final controller = AppController();
    controller.seedRoomRuntimeForTesting(
      db: db,
      profileId: 'owner-1',
      deviceId: 'owner-device',
      crypto: crypto,
    );
    return _Owner(db, crypto, controller);
  }

  /// Все вложения переписки — так, как они лежат в базе.
  Future<List<AttachmentEventV1>> attachments(String convoId) async {
    final rows = await db.listEventsChronological(convoId, limit: 50);
    final out = <AttachmentEventV1>[];
    for (final row in rows) {
      final local = ((row['local_ciphertext_b64'] as String?) ?? '').trim();
      final stored = local.isNotEmpty
          ? local
          : ((row['ciphertext_b64'] as String?) ?? '').trim();
      if (stored.isEmpty) continue;
      final payload = E2ePayloadV1.decode(
        await crypto.decrypt(base64Decode(stored)),
      );
      for (final e in payload.events) {
        if (e is AttachmentEventV1) out.add(e);
      }
    }
    return out;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('secretly-music-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (_) async {
          return tempDir.path;
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  tearDown(() => MusicTagReader.readOverride = null);

  File song(String name, [int bytes = 64]) =>
      File('${tempDir.path}/$name')
        ..writeAsBytesSync(List<int>.generate(bytes, (i) => i % 251));

  group('правила подписи', () {
    test('🔴 имя файла в поле названия — не тег', () {
      expect(
        taggedMusicTitle(_att(musicTitle: 'track.mp3', filename: 'track.mp3')),
        isNull,
      );
      expect(
        taggedMusicTitle(_att(musicTitle: 'TRACK.MP3', filename: 'track.mp3')),
        isNull,
      );
      expect(
        taggedMusicTitle(_att(musicTitle: 'Кукушка', filename: 'track.mp3')),
        'Кукушка',
      );
      expect(taggedMusicTitle(_att(musicTitle: '  Кукушка  ')), 'Кукушка');
      expect(taggedMusicTitle(_att(musicTitle: '   ')), isNull);
      expect(taggedMusicTitle(_att()), isNull);
      expect(taggedMusicArtist(_att(musicArtist: ' Виктор  Цой ')), 'Виктор Цой');
      expect(taggedMusicArtist(_att(musicArtist: '')), isNull);
    });

    test('подпись без лишних пробелов', () {
      expect(normalizeMusicLabel('  a \n  b  '), 'a b');
      expect(normalizeMusicLabel(' '), isNull);
      expect(normalizeMusicLabel(null), isNull);
    });
  });

  group('чтец тегов', () {
    test('без библиотеки и без файла — пусто, а не исключение', () async {
      expect(await MusicTagReader.read('${tempDir.path}/нет.mp3'), isNull);
      expect(await MusicTagReader.read(''), isNull);
    });

    test('🔴 на iPhone теги читает система — по каналу', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_musicTagsChannel, (call) async {
            calls.add(call);
            return <String, Object?>{
              'title': '  Группа  крови ',
              'artist': 'Кино',
            };
          });
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final tags = await MusicTagReader.read('/songs/blood.m4a');
        expect(tags?.title, 'Группа крови');
        expect(tags?.artist, 'Кино');
        expect(calls.single.method, 'read');
        expect(calls.single.arguments, {'path': '/songs/blood.m4a'});
      } finally {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_musicTagsChannel, null);
      }
    });

    test('на iPhone система молчит — пусто', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        expect(await MusicTagReader.read('/songs/none.mp3'), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('🔴 библиотека не справилась — читает система (Android, Mac)', () async {
      // Библиотека не видит M4A, у которого блок `moov` стоит после данных, —
      // так по умолчанию пишет ffmpeg. В тестах библиотеки нет вовсе, и это
      // тот же случай: чтение падает, и ответ даёт системный канал.
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_musicTagsChannel, (call) async {
            calls.add(call);
            return <String, Object?>{'title': 'Кукушка', 'artist': null};
          });
      try {
        for (final platform in [TargetPlatform.android, TargetPlatform.macOS]) {
          debugDefaultTargetPlatformOverride = platform;
          final tags = await MusicTagReader.read('/songs/moov_at_end.m4a');
          expect(tags?.title, 'Кукушка', reason: '$platform');
          expect(tags?.artist, isNull);
        }
        expect(calls, hasLength(2));
      } finally {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_musicTagsChannel, null);
      }
    });

    test('системный путь подключён на Mac и Android', () {
      final mac = File('macos/Runner/MainFlutterWindow.swift').readAsStringSync();
      expect(
        mac.contains(
          'musicTagsBridge.attach(to: flutterViewController.engine.binaryMessenger)',
        ),
        isTrue,
      );
      expect(mac.contains('name: "secretly/music_tags"'), isTrue);
      expect(mac.contains('if #available(macOS 12.0, *)'), isTrue);
      final android = File(
        'android/app/src/main/kotlin/com/secretly/secretly_app/MainActivity.kt',
      ).readAsStringSync();
      expect(android.contains('"secretly/music_tags"'), isTrue);
      expect(android.contains('METADATA_KEY_TITLE'), isTrue);
      expect(android.contains('METADATA_KEY_ARTIST'), isTrue);
      expect(android.contains('musicTagsExecutor.execute'), isTrue);
    });

    test('телефон не перечитывает файл без тегов', () {
      final chat = File('lib/ui/chat_screen.dart').readAsStringSync();
      expect(chat.contains('_musicMetadataMissBlobIds.contains(blobId)'), isTrue);
      expect(chat.contains('_musicMetadataMissBlobIds.add(blobId);'), isTrue);
      // 🔴 И плеер: очередь собирается при каждом нажатии и проходит все
      // песни чата — без этого файлы без тегов читались на каждом нажатии.
      final playback = chat.substring(
        chat.indexOf(
          '  Future<_ResolvedMusicMetadata?> _resolveMusicMetadataForPlayback(',
        ),
        chat.indexOf('  Future<void> _playAudioTrackAt('),
      );
      expect(
        playback.contains('!_musicMetadataMissBlobIds.contains(blobId) &&'),
        isTrue,
      );
      expect(playback.contains('_musicMetadataMissBlobIds.add(blobId);'), isTrue);
      expect(
        playback.contains(
          'await read.timeout(_kPlaybackTagsWait, onTimeout: () => null);',
        ),
        isTrue,
      );
    });

    test('🔴 система не ответила — пусто, а не вечное ожидание', () async {
      final never = Completer<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_musicTagsChannel, (call) => never.future);
      final previous = MusicTagReader.systemReadTimeout;
      MusicTagReader.systemReadTimeout = const Duration(milliseconds: 50);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final tags = await MusicTagReader.read('/songs/stuck.m4a').timeout(
          const Duration(seconds: 5),
        );
        expect(tags, isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        MusicTagReader.systemReadTimeout = previous;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_musicTagsChannel, null);
      }
    });

    test('iPhone: канал подключён и читает общие теги', () {
      final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(swift.contains('attachMusicTagsChannel()'), isTrue);
      expect(swift.contains('name: "secretly/music_tags"'), isTrue);
      expect(swift.contains('.commonIdentifierTitle'), isTrue);
      expect(swift.contains('.commonIdentifierArtist'), isTrue);
      expect(swift.contains('asset.load(.commonMetadata)'), isTrue);
    });
  });

  group('копия на свои устройства', () {
    test('🔴 несёт название, исполнителя и волну', () {
      final text = buildSelfMirrorAttachmentCommand(
        convoId: 'peer-1',
        msgEventId: 'm1',
        blobId: 'b1',
        fileKeyB64: 'k',
        sizeBytes: 10,
        createdAtMs: 1,
        mime: 'audio/mp4',
        waveform: const [0, 50, 100],
        musicTitle: ' Кукушка ',
        musicArtist: 'Виктор Цой',
      );
      final cmd = parseSelfMirrorAttachmentCommand(text)!;
      expect(cmd.waveform, [0, 50, 100]);
      expect(cmd.musicTitle, 'Кукушка');
      expect(cmd.musicArtist, 'Виктор Цой');
    });

    test('прежняя копия без полей читается как раньше', () {
      final legacy =
          '$kSelfMirrorAttachmentCommandPrefix'
          '${base64Url.encode(utf8.encode(jsonEncode({'v': 1, 'convoId': 'p', 'msgEventId': 'm', 'blobId': 'b', 'fileKeyB64': 'k', 'sizeBytes': 1, 'createdAtMs': 1, 'waveform': 'мусор'})))}';
      final cmd = parseSelfMirrorAttachmentCommand(legacy)!;
      expect(cmd.waveform, isNull);
      expect(cmd.musicTitle, isNull);
      expect(cmd.musicArtist, isNull);
    });

    test('🔴 второе устройство сохраняет песню с тегами, голосовое — с волной', () async {
      final owner = await _Owner.open();
      Future<void> deliver(String id, String command) async {
        final payload = E2ePayloadV1(
          senderDeviceId: 'owner-phone',
          createdAtMs: 5000,
          events: [MsgEventV1(eventId: 'wrap-$id', text: command)],
        );
        final handled = await owner.controller
            .handleDecryptedInboundPayloadForTesting(
              db: owner.db,
              msgId: 'transport-$id',
              ciphertextB64: 'AA==',
              plainBytes: Uint8List.fromList(payload.encode()),
              payload: payload,
              senderDeviceId: 'owner-phone',
              senderProfileId: 'owner-1',
              nowMs: 9000,
            );
        expect(handled, isTrue);
      }

      await deliver(
        'song',
        buildSelfMirrorAttachmentCommand(
          convoId: 'peer-1',
          msgEventId: 'song-1',
          blobId: 'blob-song',
          fileKeyB64: 'k',
          sizeBytes: 10,
          createdAtMs: 5000,
          mime: 'audio/mpeg',
          filename: 'track.mp3',
          musicTitle: 'Кукушка',
          musicArtist: 'Виктор Цой',
        ),
      );
      await deliver(
        'voice',
        buildSelfMirrorAttachmentCommand(
          convoId: 'peer-1',
          msgEventId: 'voice-1',
          blobId: 'blob-voice',
          fileKeyB64: 'k',
          sizeBytes: 10,
          createdAtMs: 5001,
          mime: 'audio/mp4',
          durationMs: 3000,
          waveform: const [10, 60, 30],
        ),
      );

      final saved = await owner.attachments('peer-1');
      final songEvent = saved.firstWhere((a) => a.eventId == 'song-1');
      expect(songEvent.musicTitle, 'Кукушка');
      expect(songEvent.musicArtist, 'Виктор Цой');
      final voiceEvent = saved.firstWhere((a) => a.eventId == 'voice-1');
      expect(voiceEvent.waveform, [10, 60, 30]);
      expect(voiceEvent.musicTitle, isNull);
    });

    test('каждая отправка в личный чат передаёт теги в копию', () {
      final src = File('lib/app/app_controller.dart').readAsStringSync();
      final calls = RegExp(
        r'_mirrorAttachmentToOwnDevices\(\n([\s\S]*?)\n          \),',
      ).allMatches(src).toList();
      expect(calls, hasLength(3));
      for (final m in calls) {
        expect(m.group(1)!.contains('musicTitle:'), isTrue);
        expect(m.group(1)!.contains('musicArtist:'), isTrue);
      }
      // Волна — у одиночных отправок (у пачки голосовых не бывает).
      expect(
        calls.where((m) => m.group(1)!.contains('waveform: waveform,')),
        hasLength(2),
      );
    });
  });

  group('комната', () {
    Future<AppDb> roomWithMember() async {
      final db = await AppDb.openForTesting();
      addTearDown(db.close);
      await db.convoEnsureGroup(groupId: 'group:music', title: 'Музыка');
      await db.groupMemberEnsure(groupId: 'group:music', memberProfileId: 'owner-1');
      await db.groupMemberEnsure(groupId: 'group:music', memberProfileId: 'peer-1');
      return db;
    }

    test('🔴 участник получает песню с названием и исполнителем', () async {
      final db = await roomWithMember();
      final crypto = DartCryptoProvider(
        Uint8List.fromList(List<int>.generate(32, (i) => i)),
      );
      final controller = AppController()
        ..seedRoomRuntimeForTesting(
          db: db,
          profileId: 'owner-1',
          deviceId: 'owner-device',
          crypto: crypto,
        );
      final envelope = <String, Object?>{
        'v': 1,
        'kind': 'attachment',
        'groupId': 'group:music',
        'groupTitle': 'Музыка',
        'msgEventId': 'room-song-1',
        'blobId': 'blob-room',
        'fileKeyB64': 'k',
        'sizeBytes': 10,
        'mime': 'audio/mpeg',
        'filename': 'track.mp3',
        'musicTitle': 'Кукушка',
        'musicArtist': 'Виктор Цой',
        'createdAtMs': 5000,
        'memberProfileIds': const ['owner-1', 'peer-1'],
        'senderProfileId': 'peer-1',
      };
      final text =
          '__secretly_group_msg_v1__:'
          '${base64Url.encode(utf8.encode(jsonEncode(envelope)))}';
      final payload = E2ePayloadV1(
        senderDeviceId: 'peer-device',
        createdAtMs: 5000,
        events: [MsgEventV1(eventId: 'wrap-room', text: text)],
      );
      final handled = await controller.handleDecryptedInboundPayloadForTesting(
        db: db,
        msgId: 'transport-room',
        ciphertextB64: 'AA==',
        plainBytes: Uint8List.fromList(payload.encode()),
        payload: payload,
        senderDeviceId: 'peer-device',
        senderProfileId: 'peer-1',
        nowMs: 9000,
      );
      expect(handled, isTrue);
      final saved = await _Owner(db, crypto, controller).attachments(
        'group:music',
      );
      final song = saved.firstWhere((a) => a.eventId == 'room-song-1');
      expect(song.musicTitle, 'Кукушка');
      expect(song.musicArtist, 'Виктор Цой');
      expect(song.filename, 'track.mp3');
    });

    test('🔴 отправитель кладёт теги в конверт — одиночный и пачкой', () {
      final src = File('lib/app/app_controller.dart').readAsStringSync();
      final single = src.substring(
        src.indexOf('  Future<String> sendGroupAttachmentFile({'),
        src.indexOf(
          '  Future<Map<String, List<MessageReaction>>> loadMessageReactions({',
        ),
      );
      expect(single.contains("'musicTitle': musicTitle!.trim(),"), isTrue);
      expect(single.contains("'musicArtist': musicArtist!.trim(),"), isTrue);
      final batch = src.substring(
        src.indexOf('  Future<List<String>> sendGroupAttachmentFiles({'),
        src.indexOf('  Future<void> ensureDemoChat() async {'),
      );
      expect(
        batch.contains(
          "if (input.musicTitle != null) 'musicTitle': input.musicTitle,",
        ),
        isTrue,
      );
      expect(
        batch.contains(
          "if (input.musicArtist != null) 'musicArtist': input.musicArtist,",
        ),
        isTrue,
      );
    });
  });

  group('очередь песен телефона', () {
    PendingAudioUpload pendingSong(File f, {required String convoId}) =>
        PendingAudioUpload(
          id: 'a-${f.path.hashCode}',
          filePath: f.path,
          mime: 'audio/mpeg',
          totalBytes: f.lengthSync(),
          isVoice: false,
          convoId: convoId,
          targetId: convoId,
          title: f.uri.pathSegments.last,
        );

    test('🔴 ждёт теги, даже если они приходят позже старта очереди', () async {
      final owner = await _Owner.open();
      final f = song('kukushka.mp3');
      final pending = pendingSong(f, convoId: 'owner-1');
      final tagsArrive = Completer<void>();
      // Как на экране чата: чтение начинается вместе с постановкой в очередь.
      pending.tagsReady = () async {
        await tagsArrive.future;
        pending.title = 'Кукушка';
        pending.artist = 'Виктор Цой';
        pending.tagsFromFile = true;
      }();
      owner.controller.enqueueAudioUpload(pending);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(
        owner.controller.pendingAudioUploadsFor('owner-1'),
        hasLength(1),
        reason: 'без тегов песня не уходит',
      );
      tagsArrive.complete();
      await _until(
        () => owner.controller.pendingAudioUploadsFor('owner-1').isEmpty,
      );
      final sent = (await owner.attachments('owner-1')).single;
      expect(sent.musicTitle, 'Кукушка');
      expect(sent.musicArtist, 'Виктор Цой');
      expect(sent.filename, 'kukushka.mp3');
    });

    test('🔴 тегов нет — имя файла названием не уходит', () async {
      final owner = await _Owner.open();
      final f = song('noname.mp3');
      final pending = pendingSong(f, convoId: 'owner-1')
        ..tagsReady = Future<void>.value();
      owner.controller.enqueueAudioUpload(pending);
      await _until(
        () => owner.controller.pendingAudioUploadsFor('owner-1').isEmpty,
      );
      final sent = (await owner.attachments('owner-1')).single;
      expect(sent.musicTitle, isNull);
      expect(sent.musicArtist, isNull);
      expect(sent.filename, 'noname.mp3');
    });

    test('в тегах один исполнитель — названия нет, исполнитель есть', () async {
      final owner = await _Owner.open();
      final f = song('artist_only.mp3');
      final pending = pendingSong(f, convoId: 'owner-1');
      pending.tagsReady = () async {
        pending.artist = 'Кино';
        pending.tagsFromFile = true;
      }();
      owner.controller.enqueueAudioUpload(pending);
      await _until(
        () => owner.controller.pendingAudioUploadsFor('owner-1').isEmpty,
      );
      final sent = (await owner.attachments('owner-1')).single;
      expect(sent.musicTitle, isNull);
      expect(sent.musicArtist, 'Кино');
    });

    test('упавшее чтение тегов не роняет отправку', () async {
      final owner = await _Owner.open();
      final f = song('broken.mp3');
      final pending = pendingSong(f, convoId: 'owner-1')
        ..tagsReady = Future<void>.error(StateError('теги не прочлись'));
      final errors = <AttachmentUploadErrorEvent>[];
      final sub = owner.controller.attachmentUploadErrors.listen(errors.add);
      addTearDown(sub.cancel);
      owner.controller.enqueueAudioUpload(pending);
      await _until(
        () => owner.controller.pendingAudioUploadsFor('owner-1').isEmpty,
      );
      expect(errors, isEmpty);
      expect((await owner.attachments('owner-1')).single.musicTitle, isNull);
    });

    test('🔴 голосовое уходит голосовым: волна, без названия и тегов', () async {
      final owner = await _Owner.open();
      final f = song('voice_1.m4a');
      owner.controller.enqueueAudioUpload(
        PendingAudioUpload(
          id: 'v1',
          filePath: f.path,
          mime: 'audio/mp4',
          totalBytes: f.lengthSync(),
          isVoice: true,
          convoId: 'owner-1',
          targetId: 'owner-1',
          waveform: const [5, 40, 90],
        ),
      );
      await _until(
        () => owner.controller.pendingAudioUploadsFor('owner-1').isEmpty,
      );
      final sent = (await owner.attachments('owner-1')).single;
      expect(sent.waveform, [5, 40, 90]);
      expect(sent.musicTitle, isNull);
      expect(sent.musicArtist, isNull);
      // 🔴 Имя — как у выпущенной версии: по нему получатель называет файл
      // при сохранении (`voice_…`, а не `music_…`).
      expect(sent.filename, 'voice_1.m4a');
    });

    test('голосовое с «голосовым» типом уходит без имени, как раньше', () async {
      final owner = await _Owner.open();
      final f = song('voice_2.ogg');
      owner.controller.enqueueAudioUpload(
        PendingAudioUpload(
          id: 'v2',
          filePath: f.path,
          mime: 'audio/ogg',
          totalBytes: f.lengthSync(),
          isVoice: true,
          convoId: 'owner-1',
          targetId: 'owner-1',
          waveform: const [7, 7],
        ),
      );
      await _until(
        () => owner.controller.pendingAudioUploadsFor('owner-1').isEmpty,
      );
      final sent = (await owner.attachments('owner-1')).single;
      expect(sent.filename, isNull);
      expect(sent.waveform, [7, 7]);
    });

    test('экран чата: голосовое узнаётся по волне, теги — до очереди', () {
      final src = File('lib/ui/chat_screen.dart').readAsStringSync();
      expect(
        src.contains(
          '_isVoiceMessageMime(mime) || (waveform?.isNotEmpty ?? false);',
        ),
        isTrue,
      );
      final enqueue = src.substring(
        src.indexOf('  Future<void> _enqueuePendingAudioFile({'),
        src.indexOf('  Future<void> _startVoiceRecording() async {'),
      );
      expect(
        enqueue.indexOf('pending.tagsReady = '),
        lessThan(enqueue.indexOf('enqueueAudioUpload(pending)')),
        reason: 'очередь стартует синхронно — теги надо повесить ДО неё',
      );
      expect(enqueue.contains('pending.tagsFromFile = true;'), isTrue);
      expect(src.contains('waveform: a.waveform,'), isTrue);
    });
  });

  group('пересылка', () {
    test('🔴 пересланная песня уходит с тегами', () async {
      final owner = await _Owner.open();
      final f = song('fwd.mp3');
      owner.controller.enqueuePhotoUpload(
        PendingPhotoUpload(
          id: 'fwd-1',
          filePath: f.path,
          mime: 'audio/mpeg',
          caption: '',
          totalBytes: f.lengthSync(),
          convoId: 'owner-1',
          targetId: 'owner-1',
          filename: 'fwd.mp3',
          asFile: true,
          musicTitle: 'Кукушка',
          musicArtist: 'Виктор Цой',
        ),
      );
      await _until(
        () => owner.controller.pendingPhotoUploadsFor('owner-1').isEmpty,
      );
      final sent = (await owner.attachments('owner-1')).single;
      expect(sent.musicTitle, 'Кукушка');
      expect(sent.musicArtist, 'Виктор Цой');
    });

    test('🔴 пересланное голосовое остаётся голосовым', () async {
      final owner = await _Owner.open();
      final f = song('voice_fwd.m4a');
      owner.controller.enqueuePhotoUpload(
        PendingPhotoUpload(
          id: 'fwd-voice',
          filePath: f.path,
          mime: 'audio/mp4',
          caption: '',
          totalBytes: f.lengthSync(),
          convoId: 'owner-1',
          targetId: 'owner-1',
          waveform: const [7, 70, 35],
          durationMs: 4200,
        ),
      );
      await _until(
        () => owner.controller.pendingPhotoUploadsFor('owner-1').isEmpty,
      );
      final sent = (await owner.attachments('owner-1')).single;
      expect(sent.waveform, [7, 70, 35]);
      expect(sent.durationMs, 4200);
      expect(sent.musicTitle, isNull);
    });

    test('телефон и компьютер берут теги из исходного сообщения', () {
      final phone = File('lib/ui/chat_screen.dart').readAsStringSync();
      expect(phone.contains('musicTitle: taggedMusicTitle(event),'), isTrue);
      expect(phone.contains('musicArtist: taggedMusicArtist(event),'), isTrue);
      final desk = File(
        'lib/ui/desktop/app/desktop_chats_section.dart',
      ).readAsStringSync();
      expect(
        RegExp('musicTitle: attachment.musicTitle,').allMatches(desk),
        hasLength(2),
      );
      expect(phone.contains('waveform: event.waveform,'), isTrue);
      expect(
        RegExp('waveform: attachment.waveform,').allMatches(desk),
        hasLength(2),
      );
    });
  });

  group('компьютер', () {
    test('🔴 окно отправки читает теги песни', () async {
      MusicTagReader.readOverride = (path) async =>
          const MusicTags(title: 'Кукушка', artist: 'Виктор Цой');
      final f = OutgoingFile(
        path: '/music/kukushka.mp3',
        name: 'kukushka.mp3',
        sizeBytes: 4 * 1024 * 1024,
      );
      expect(f.kind, OutgoingKind.audio);
      await OutgoingMediaPrep.prepare(f);
      expect(f.musicTitle, 'Кукушка');
      expect(f.musicArtist, 'Виктор Цой');
    });

    test('теги не прочлись — окно отправки не падает', () async {
      MusicTagReader.readOverride = (path) async => throw StateError('нет');
      final f = OutgoingFile(
        path: '/music/x.mp3',
        name: 'x.mp3',
        sizeBytes: 10,
      );
      await OutgoingMediaPrep.prepare(f);
      expect(f.prepared, isTrue);
      expect(f.musicTitle, isNull);
    });

    test('🔴 теги уходят в очередь и видны в заготовке', () async {
      final f =
          OutgoingFile(
              path: '/music/kukushka.mp3',
              name: 'kukushka.mp3',
              sizeBytes: 2048,
            )
            ..musicTitle = 'Кукушка'
            ..musicArtist = 'Виктор Цой'
            ..prepared = true;
      final batches = <PendingAttachmentBatchUpload>[];
      await enqueueDesktopMediaSend(
        enqueue: batches.add,
        result: SendMediaResult(
          files: [f],
          caption: '',
          sendAsFiles: false,
          grouped: true,
        ),
        convoId: 'peer-1',
        peerProfileId: 'peer-1',
        sendText: (_, _) async {},
      );
      final hint = batches.single.hints.single;
      expect(hint.musicTitle, 'Кукушка');
      expect(hint.musicArtist, 'Виктор Цой');
      final row = desktopUploadRows(
        batches,
        selfName: 'Я',
        timeLabel: (_) => '12:00',
      ).single;
      expect(row.attachment!.musicTitle, 'Кукушка');
      expect(row.attachment!.musicArtist, 'Виктор Цой');
    });

    test('🔴 пачка передаёт теги в сообщение', () async {
      final owner = await _Owner.open();
      final f = song('batch.mp3');
      final batch = PendingAttachmentBatchUpload(
        id: 'mb1',
        items: [
          PendingPhotoUpload(
            id: 'mb1_0',
            filePath: f.path,
            mime: 'audio/mpeg',
            caption: '',
            totalBytes: f.lengthSync(),
            filename: 'batch.mp3',
            asFile: true,
          ),
        ],
        hints: const [
          PendingUploadHints(musicTitle: 'Кукушка', musicArtist: 'Виктор Цой'),
        ],
        convoId: 'owner-1',
        targetId: 'owner-1',
      );
      owner.controller.enqueueAttachmentBatchUpload(batch);
      await _until(
        () =>
            owner.controller.pendingAttachmentBatchUploadsFor('owner-1').isEmpty,
      );
      final sent = (await owner.attachments('owner-1')).single;
      expect(sent.musicTitle, 'Кукушка');
      expect(sent.musicArtist, 'Виктор Цой');
      expect(sent.filename, 'batch.mp3');
    });

    testWidgets('строка песни в окне: название, исполнитель и размер', (
      t,
    ) async {
      t.view.physicalSize = const Size(1400, 1000);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final f =
          OutgoingFile(
              path: '/music/kukushka.mp3',
              name: 'kukushka.mp3',
              sizeBytes: 2048,
            )
            ..musicTitle = 'Кукушка'
            ..musicArtist = 'Виктор Цой'
            ..prepared = true;
      await t.pumpWidget(
        DColors(
          colors: kDColorsDark,
          child: MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showSendMediaDialog(
                      ctx,
                      files: [f],
                      maxBytes: 0,
                    ),
                    child: const Text('открыть'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('открыть'));
      await t.pumpAndSettle();
      expect(find.textContaining('Кукушка', findRichText: true), findsWidgets);
      expect(find.textContaining('Виктор Цой ·'), findsOneWidget);
      expect(find.textContaining('kukushka.mp3', findRichText: true), findsNothing);
    });

    test('полученные песни без тегов подписываются по скачанному файлу', () {
      final src = File(
        'lib/ui/desktop/app/desktop_chats_section.dart',
      ).readAsStringSync();
      expect(src.contains('musicTitle: taggedMusicTitle(payload),'), isTrue);
      expect(src.contains('attachment = _withProbedMusicTags('), isTrue);
      expect(
        src.contains('_probeMusicTagsIfUntagged(messageId, a, fetched.path);'),
        isTrue,
      );
      expect(src.contains('await MusicTagReader.read(path);'), isTrue);
      final bubble = MessageAttachment(
        kind: MessageAttachmentKind.audio,
        blobId: 'b',
        payloadEventId: 'p',
        musicTitle: 'Старое',
      ).copyWith(musicArtist: 'Кино');
      expect(bubble.musicTitle, 'Старое');
      expect(bubble.musicArtist, 'Кино');
    });
  });

  group('показ на телефоне', () {
    test('🔴 пузырь, галерея и плеер ставят теги сообщения первыми', () {
      final chat = File('lib/ui/chat_screen.dart').readAsStringSync();
      final bubble = chat.substring(
        chat.indexOf('  _ResolvedMusicMetadata _resolvedMusicMetadataForAttachment('),
        chat.indexOf('  Future<File> _ensureAttachmentFile('),
      );
      expect(
        bubble.contains('final payloadTitle = taggedMusicTitle(attachment);'),
        isTrue,
      );
      final player = chat.substring(
        chat.indexOf('  Future<_ResolvedMusicMetadata?> _resolveMusicMetadataForPlayback('),
        chat.indexOf('  Future<void> _playAudioTrackAt('),
      );
      expect(player.contains('taggedMusicTitle(attachment)'), isTrue);
      expect(
        player.indexOf('payloadTitle ??'),
        lessThan(player.indexOf('probed?.title')),
      );
      expect(chat.contains('await MusicTagReader.read(filePath);'), isTrue);
      expect(chat.contains('AudioTags.read('), isFalse);
      final gallery = File(
        'lib/ui/widgets/conversation_media_gallery.dart',
      ).readAsStringSync();
      expect(gallery.contains('taggedMusicTitle(item.attachment)'), isTrue);
      final profile = File('lib/ui/profile_screen.dart').readAsStringSync();
      expect(profile.contains('AudioTags.read('), isFalse);
      expect(profile.contains('MusicTagReader.read(filePath)'), isTrue);
    });
  });
}
