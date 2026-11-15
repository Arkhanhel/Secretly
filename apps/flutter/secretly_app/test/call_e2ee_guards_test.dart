// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 Сторожа сквозного шифрования созвонов (ТЗ E2EE созвонов, Т-Ю7).
//
// Каждая проверка держит одну защиту, которую легко снять случайной правкой:
// без неё медиа или ключ ушли бы открытыми, а заметить это без шпиона на
// стенде нельзя.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

/// Только код: комментарии (они как раз объясняют, чего НЕ делаем) не
/// должны ни срабатывать сторожем, ни заменять код.
String _code(String src) => src
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

Iterable<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  final controller = _code(
    _read('lib/rooms/call_e2ee/e2ee_room_call_media_controller.dart'),
  );

  group('медиа зашифрованного созвона', () {
    test('E2EE-менеджер LiveKit не используется', () {
      // Свой слой поверх flutter_webrtc: у менеджера LiveKit 2.4.0 ловушки
      // ЛК-1…ЛК-16.
      expect(controller.contains('e2eeOptions'), isFalse);
      expect(controller.contains('E2EEOptions'), isFalse);
      expect(controller.contains('setE2EEEnabled'), isFalse);
      expect(controller.contains('e2eeManager'), isFalse);
      expect(controller.contains('BaseKeyProvider'), isFalse);
    });

    test('ЛК-12: dynacast выключен, резервного кодека нет, VP8', () {
      expect(controller.contains('dynacast: false'), isTrue);
      expect(controller.contains('dynacast: true'), isFalse);
      expect(
        controller.contains(
          'backupVideoCodec: lk.BackupVideoCodec(enabled: false)',
        ),
        isTrue,
      );
      expect(controller.contains("videoCodec: 'vp8'"), isTrue);
    });

    test('ЛК-5/ЛК-16: подписка вручную, чужая дорожка глушится сразу', () {
      // Настройку соединения собирает общая функция (Э5: под цензурой
      // добавляется «только через сервер»), но подписка ОБЯЗАНА остаться
      // ручной — поэтому сторож смотрит на аргумент в точке соединения, а не
      // на литерал `lk.ConnectOptions`.
      final connectAt = controller.indexOf('await room.connect(');
      expect(connectAt, greaterThan(0));
      final connectCall = controller.substring(connectAt, connectAt + 400);
      expect(connectCall.contains('autoSubscribe: false'), isTrue);
      expect(connectCall.contains('autoSubscribe: true'), isFalse);
      // И сама функция не смеет включать подписку за нас.
      final stealth = _code(_read('lib/rooms/room_call_stealth.dart'));
      expect(stealth.contains('autoSubscribe: autoSubscribe'), isTrue);
      expect(stealth.contains('autoSubscribe: true'), isFalse);
      final onSub = controller.indexOf('void _onTrackSubscribed(');
      expect(onSub, greaterThan(0));
      final body = controller.substring(onSub, onSub + 600);
      // Первое действие обработчика — заглушить, до любого await.
      final mute = body.indexOf('track.mediaStreamTrack.enabled = false;');
      final firstAwait = body.indexOf('await ');
      expect(mute, greaterThan(0));
      expect(firstAwait == -1 || mute < firstAwait, isTrue);
    });

    test('🔴 ЛК-12 (2.13): сервер не может включить dynacast в зашифрованном созвоне', () {
      // С livekit_client 2.13 сервер, не предложив VP8, переводит клиента на
      // VP9 или AV1, а те сами включают dynacast на всю комнату. При
      // включённом dynacast возможен резервный кодек — второй отправитель
      // камеры без шифратора. После публикации контроллер обязан проверить
      // действующий dynacast и, если тот включён, снять дорожку и закрыться.
      final at = controller.indexOf('final published = await publish(track);');
      expect(at, greaterThan(0));
      final body = controller.substring(at, at + 2600);
      final check = body.indexOf('roomOptions.dynacast');
      final enable = body.indexOf('track.mediaStreamTrack.enabled = true;');
      expect(check, greaterThan(0), reason: 'нет проверки dynacast после публикации');
      expect(enable, greaterThan(check),
          reason: 'проверка должна стоять ДО включения дорожки');
      final branch = body.substring(check, check + 260);
      expect(branch.contains('removePublishedTrack'), isTrue);
      expect(branch.contains("'dynacast_forced'"), isTrue);
    });

    test('ЛК-2/ЛК-3/ЛК-13: параметры провайдера ключей', () {
      expect(controller.contains('sharedKey: false'), isTrue);
      expect(controller.contains('ratchetWindowSize: 0'), isTrue);
      expect(controller.contains('uncryptedMagicBytes: null'), isTrue);
      expect(controller.contains('failureTolerance: -1'), isTrue);
      expect(controller.contains('keyRingSize: kCallKeyRingSize'), isTrue);
      expect(controller.contains('setSifTrailer'), isFalse);
      expect(controller.contains('ratchetKey('), isFalse);
    });

    test('ЛК-6/ЛК-13: своя дорожка публикуется выключенной', () {
      final at = controller.indexOf('final track = await create();');
      expect(at, greaterThan(0));
      final body = controller.substring(at, at + 400);
      final off = body.indexOf('track.mediaStreamTrack.enabled = false;');
      final publish = body.indexOf('await publish(track)');
      expect(off, greaterThan(0));
      expect(publish, greaterThan(off), reason: 'выключить — ДО публикации');
    });

    test('ЛК-12: сверка всех отправителей соединения', () {
      expect(controller.contains('pc.getSenders()'), isTrue);
      expect(controller.contains('Timer.periodic(_kSweepEvery'), isTrue);
    });

    test('каналы данных и RPC не используются', () {
      expect(controller.contains('publishData('), isFalse);
      expect(controller.contains('performRpc'), isFalse);
    });
  });

  test('🔴 ЛК-19: нигде в приложении не включается нативный журнал WebRTC', () {
    for (final f in _dartFiles('lib')) {
      final src = _code(f.readAsStringSync());
      for (final needle in const [
        'RTCSetMinDebugLogLevel',
        'enableLogToDebugOutput',
        'injectLoggable',
        'setE2EEEnabled(',
        // flutter_webrtc 1.6 добавил публичный переключатель, который
        // направляет нативный журнал WebRTC в Dart. В нативных библиотеках
        // есть строка уровня INFO с сырым ключом, солью и выведенным ключом
        // (ЛК-19) — включить его значит увести ключи в журнал приложения.
        'Helper.setLogger',
        'setLogger(',
      ]) {
        expect(src.contains(needle), isFalse, reason: '${f.path}: $needle');
      }
    }
  });

  group('ключи в контроллере приложения', () {
    final ac = _code(_read('lib/app/app_controller.dart'));

    test('ЗР-14: отправка ключа — адресно, коротко, без повтора по NACK и '
        'без открытого текста в базе', () {
      final at = ac.indexOf('Future<bool> sendRoomCallKeyCommand({');
      expect(at, greaterThan(0));
      final body = ac.substring(at, ac.indexOf('\n  }\n', at));
      expect(body.contains('ttlSeconds: 90'), isTrue);
      expect(body.contains('targetDeviceIds: <String>[dev]'), isTrue);
      expect(body.contains('eventIdRef'), isFalse);
      expect(body.contains('queueIfNoDevices'), isFalse);
      expect(body.contains('transportMetaJson'), isFalse);
    });

    test('ЗР-14: команда ключа всегда «обработана» и только по попарной '
        'сессии с подтверждённым отправителем', () {
      final at = ac.indexOf(
        'if (RoomCallKeyCommandCodec.isEncodedText(msgEvent.text)) {',
      );
      expect(at, greaterThan(0));
      final body = ac.substring(at, at + 1800);
      expect(body.contains('senderAttested &&'), isTrue);
      expect(body.contains('roomKeyWireDepth == 0'), isTrue);
      final handled = body.indexOf('handledCommand = true;');
      final cont = body.indexOf('continue;');
      expect(handled, greaterThan(0));
      expect(cont, greaterThan(handled));
    });

    test('ЗР-10: медиа получает снимок только через фильтр желания', () {
      final mgr = _read('lib/rooms/room_call_manager.dart');
      expect(mgr.contains('applyRoomCallCaptureIntent('), isTrue);
      expect(
        mgr.contains('await _mediaController!.syncSession(session: session);'),
        isFalse,
      );
    });

    test('зашифрованный созвон никогда не уходит в открытый движок', () {
      final mc = _read('lib/rooms/room_call_media_controller.dart');
      expect(
        mc.contains(
          'isE2eeRoomMediaContract(session.contractVersion)\n'
          '          ? _RoomCallMediaRuntimeKind.livekitE2ee',
        ),
        isTrue,
      );
      expect(
        mc.contains(
          "UnavailableE2eeRoomCallMediaController('transport_unavailable')",
        ),
        isTrue,
      );
    });
  });
}
