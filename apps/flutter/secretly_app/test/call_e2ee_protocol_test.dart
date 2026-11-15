// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Протокол ключей зашифрованного созвона (ТЗ E2EE созвонов, §4.1–§4.3).
// Каждая проверка приёма закреплена тестом, который ломается, если проверку
// убрать.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/rooms/call_e2ee/call_e2ee_protocol.dart';

Uint8List _key(int seed) =>
    Uint8List.fromList(List<int>.generate(32, (i) => (i * 7 + seed) & 0xff));

const _nowMs = 1760000000000;
const _room = 'room-1';
const _call = 'call-1';
const _pid = 'prof-A';
const _did = 'dev-A';

RoomCallKeyGrant _grant({
  String roomId = _room,
  String callId = _call,
  String? identity,
  int epoch = 1,
  int keyIndex = 0,
  Uint8List? key,
  int sentAtMs = _nowMs,
}) => RoomCallKeyGrant(
  roomId: roomId,
  callId: callId,
  identity: identity ?? roomMediaParticipantIdentity(_pid, _did),
  sentAtMs: sentAtMs,
  epoch: epoch,
  keyIndex: keyIndex,
  key: key ?? _key(1),
  reason: RoomCallKeyReason.join,
);

RoomCallKeyCheckInput _input({
  String sender = _did,
  String profile = _pid,
  bool ownsDevice = true,
  bool member = true,
  bool inCall = true,
  String? activeRoom = _room,
  String? activeCall = _call,
  bool e2ee = true,
  int? lastEpoch,
  Uint8List? lastKey,
  int grantsLastMinute = 0,
}) => RoomCallKeyCheckInput(
  pairwiseSenderDeviceId: sender,
  senderProfileId: profile,
  senderDeviceBelongsToProfile: ownsDevice,
  senderIsActiveRoomMember: member,
  senderDeviceInCallSnapshot: inCall,
  activeRoomId: activeRoom,
  activeCallId: activeCall,
  activeCallIsE2ee: e2ee,
  lastEpochFromSender: lastEpoch,
  lastKeyFromSender: lastKey,
  grantsFromSenderLastMinute: grantsLastMinute,
  nowMs: _nowMs,
);

void main() {
  group('идентичность совпадает с реле (общий тест-вектор)', () {
    test('участник', () {
      expect(
        roomMediaParticipantIdentity('prof-TEST-1', 'dev:TEST/1'),
        'secretly-participant-dev_TEST_1-Dz7mVD6s8H',
      );
    });

    test('не-ASCII и предел 18 знаков', () {
      expect(
        roomMediaParticipantIdentity('p', 'дев-ü-устройство-очень-длинное'),
        'secretly-participant-___-_-__________-_-IWuyNJ7ZjG',
      );
    });

    test('пустые значения дают «x»', () {
      expect(
        roomMediaParticipantIdentity('', ''),
        'secretly-participant-x-56wHhmaOD_',
      );
    });
  });

  test('контракт: незнакомое — открытый созвон', () {
    expect(normalizeRoomMediaContract(null), kRoomMediaContractV1);
    expect(normalizeRoomMediaContract('nonsense'), kRoomMediaContractV1);
    expect(
      normalizeRoomMediaContract(' room_media_e2ee_v1 '),
      kRoomMediaContractE2eeV1,
    );
    expect(isE2eeRoomMediaContract('room_media_v1'), isFalse);
  });

  group('кодек команд', () {
    test('ключ: туда и обратно, ключ не меняется', () {
      final g = _grant(epoch: 3, keyIndex: 5, key: _key(9));
      final decoded = RoomCallKeyCommandCodec.decode(
        RoomCallKeyCommandCodec.encode(g),
      );
      expect(decoded, isA<RoomCallKeyGrant>());
      final d = decoded! as RoomCallKeyGrant;
      expect(d.epoch, 3);
      expect(d.keyIndex, 5);
      expect(d.key, _key(9));
      expect(d.identity, g.identity);
      expect(d.reason, RoomCallKeyReason.join);
    });

    test('просьба: туда и обратно', () {
      const r = RoomCallKeyRequest(
        roomId: _room,
        callId: _call,
        identity: 'secretly-participant-a-b',
        sentAtMs: _nowMs,
        want: 'secretly-participant-c-d',
      );
      final d = RoomCallKeyCommandCodec.decode(
        RoomCallKeyCommandCodec.encode(r),
      );
      expect(d, isA<RoomCallKeyRequest>());
      expect((d! as RoomCallKeyRequest).want, r.want);
    });

    test('чужой префикс, другая версия, другой контракт — не команда', () {
      String wrap(Map<String, Object?> m) =>
          '${RoomCallKeyCommandCodec.prefix}'
          '${base64Url.encode(utf8.encode(jsonEncode(m)))}';
      final base = <String, Object?>{
        'v': 1,
        'action': 'room_call_key',
        'contract': kRoomMediaContractE2eeV1,
        'roomId': _room,
        'callId': _call,
        'identity': 'x',
        'epoch': 1,
        'keyIndex': 0,
        'key': base64Url.encode(_key(1)),
        'reason': 'join',
        'sentAtMs': _nowMs,
      };
      expect(RoomCallKeyCommandCodec.decode(wrap(base)), isNotNull);
      expect(RoomCallKeyCommandCodec.decode('просто текст'), isNull);
      expect(RoomCallKeyCommandCodec.decode(wrap({...base, 'v': 2})), isNull);
      expect(
        RoomCallKeyCommandCodec.decode(
          wrap({...base, 'contract': 'room_media_v1'}),
        ),
        isNull,
      );
      expect(
        RoomCallKeyCommandCodec.decode(wrap({...base, 'reason': 'other'})),
        isNull,
      );
      expect(
        RoomCallKeyCommandCodec.decode(wrap({...base, 'epoch': '1'})),
        isNull,
      );
      expect(
        RoomCallKeyCommandCodec.decode('${RoomCallKeyCommandCodec.prefix}@@@'),
        isNull,
      );
    });

    test('🔴 toString не выдаёт ключ', () {
      final g = _grant(key: _key(42));
      final text = g.toString();
      expect(text.contains(base64Url.encode(_key(42))), isFalse);
      expect(text.contains(base64.encode(_key(42))), isFalse);
      expect(text.contains(callKeyFingerprint(_key(42))), isTrue);
    });
  });

  group('проверка ключа при приёме (§4.2)', () {
    test('всё сходится — принять', () {
      expect(
        checkRoomCallKeyGrant(_grant(), _input()),
        RoomCallKeyVerdict.accept,
      );
    });

    test('1. нет попарного отправителя', () {
      expect(
        checkRoomCallKeyGrant(_grant(), _input(sender: '')),
        RoomCallKeyVerdict.rejectNotPairwiseSender,
      );
    });

    test('2. устройство не этого профиля', () {
      expect(
        checkRoomCallKeyGrant(_grant(), _input(ownsDevice: false)),
        RoomCallKeyVerdict.rejectDeviceNotOfProfile,
      );
    });

    test('2. не член комнаты (вышел или забанен)', () {
      expect(
        checkRoomCallKeyGrant(_grant(), _input(member: false)),
        RoomCallKeyVerdict.rejectNotRoomMember,
      );
    });

    test('2. устройства нет в созвоне', () {
      expect(
        checkRoomCallKeyGrant(_grant(), _input(inCall: false)),
        RoomCallKeyVerdict.rejectNotInCall,
      );
    });

    test('3. идентичность не от (P, D) отправителя', () {
      final g = _grant(identity: roomMediaParticipantIdentity(_pid, 'dev-B'));
      expect(
        checkRoomCallKeyGrant(g, _input()),
        RoomCallKeyVerdict.rejectIdentityMismatch,
      );
    });

    test('4. чужой созвон', () {
      expect(
        checkRoomCallKeyGrant(_grant(callId: 'call-other'), _input()),
        RoomCallKeyVerdict.rejectWrongCall,
      );
      expect(
        checkRoomCallKeyGrant(_grant(), _input(activeCall: null)),
        RoomCallKeyVerdict.rejectWrongCall,
      );
    });

    test('4. созвон открытый', () {
      expect(
        checkRoomCallKeyGrant(_grant(), _input(e2ee: false)),
        RoomCallKeyVerdict.rejectNotE2eeCall,
      );
    });

    test('5. длина ключа и ячейка', () {
      expect(
        checkRoomCallKeyGrant(_grant(key: Uint8List(16)), _input()),
        RoomCallKeyVerdict.rejectMalformedKey,
      );
      expect(
        checkRoomCallKeyGrant(_grant(keyIndex: 16), _input()),
        RoomCallKeyVerdict.rejectMalformedKey,
      );
      expect(
        checkRoomCallKeyGrant(_grant(keyIndex: -1), _input()),
        RoomCallKeyVerdict.rejectMalformedKey,
      );
      expect(
        checkRoomCallKeyGrant(_grant(epoch: 0), _input()),
        RoomCallKeyVerdict.rejectMalformedKey,
      );
    });

    test('5. эпоха: старше — отказ, та же с тем же ключом — дубль, '
        'та же с другим — конфликт', () {
      expect(
        checkRoomCallKeyGrant(_grant(epoch: 2), _input(lastEpoch: 3)),
        RoomCallKeyVerdict.rejectStaleEpoch,
      );
      expect(
        checkRoomCallKeyGrant(
          _grant(epoch: 3, key: _key(5)),
          _input(lastEpoch: 3, lastKey: _key(5)),
        ),
        RoomCallKeyVerdict.duplicate,
      );
      expect(
        checkRoomCallKeyGrant(
          _grant(epoch: 3, key: _key(6)),
          _input(lastEpoch: 3, lastKey: _key(5)),
        ),
        RoomCallKeyVerdict.rejectEpochConflict,
      );
      expect(
        checkRoomCallKeyGrant(_grant(epoch: 4), _input(lastEpoch: 3)),
        RoomCallKeyVerdict.accept,
      );
    });

    test('6. часы: ±10 минут', () {
      const tenMin = 10 * 60 * 1000;
      expect(
        checkRoomCallKeyGrant(_grant(sentAtMs: _nowMs - tenMin - 1), _input()),
        RoomCallKeyVerdict.rejectClock,
      );
      expect(
        checkRoomCallKeyGrant(_grant(sentAtMs: _nowMs + tenMin + 1), _input()),
        RoomCallKeyVerdict.rejectClock,
      );
      expect(
        checkRoomCallKeyGrant(_grant(sentAtMs: _nowMs - tenMin), _input()),
        RoomCallKeyVerdict.accept,
      );
    });

    test('7. не больше 20 ключей в минуту', () {
      expect(
        checkRoomCallKeyGrant(_grant(), _input(grantsLastMinute: 19)),
        RoomCallKeyVerdict.accept,
      );
      expect(
        checkRoomCallKeyGrant(_grant(), _input(grantsLastMinute: 20)),
        RoomCallKeyVerdict.rejectRateLimited,
      );
    });
  });

  group('проверка просьбы о ключе (§4.3)', () {
    final self = roomMediaParticipantIdentity('prof-ME', 'dev-ME');
    RoomCallKeyRequest req({String? want, String callId = _call}) =>
        RoomCallKeyRequest(
          roomId: _room,
          callId: callId,
          identity: roomMediaParticipantIdentity(_pid, _did),
          sentAtMs: _nowMs,
          want: want ?? self,
        );

    test('просят наш ключ — ответить', () {
      expect(
        checkRoomCallKeyRequest(req(), _input(), selfIdentity: self),
        RoomCallKeyVerdict.accept,
      );
    });

    test('просят чужой ключ — не отвечаем', () {
      expect(
        checkRoomCallKeyRequest(
          req(want: 'secretly-participant-other'),
          _input(),
          selfIdentity: self,
        ),
        RoomCallKeyVerdict.rejectWrongCall,
      );
    });

    test('спрашивающего нет в созвоне — не отвечаем', () {
      expect(
        checkRoomCallKeyRequest(
          req(),
          _input(inCall: false),
          selfIdentity: self,
        ),
        RoomCallKeyVerdict.rejectNotInCall,
      );
    });

    test('спрашивающий не член комнаты — не отвечаем', () {
      expect(
        checkRoomCallKeyRequest(
          req(),
          _input(member: false),
          selfIdentity: self,
        ),
        RoomCallKeyVerdict.rejectNotRoomMember,
      );
    });
  });
}
