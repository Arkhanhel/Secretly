// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';

/// The three room-key wire types (docs/TZ_ROOM_SENDER_KEY_2026-07-29.md §4).
///
/// These land in a format that a RELEASED client already parses, so the tests
/// that matter most are about what a client does with input it was not built
/// for — in both directions.
void main() {
  Uint8List filled(int n, int b) => Uint8List.fromList(List.filled(n, b));

  List<E2eEventV1> roundTrip(E2eEventV1 event) => E2ePayloadV1.decode(
    E2ePayloadV1(
      senderDeviceId: 'devA',
      createdAtMs: 1000,
      events: [event],
    ).encode(),
  ).events;

  group('gkey', () {
    test('survives the wire with the chain key intact', () {
      final chain = Uint8List.fromList(List.generate(32, (i) => i));
      final out = roundTrip(
        RoomKeyEventV1(
          roomId: 'group:r1',
          epoch: 3,
          counter: 41,
          chainKey: chain,
          issuedAtMs: 1700000000000,
        ),
      );
      final got = out.single as RoomKeyEventV1;
      expect(got.roomId, 'group:r1');
      expect(got.epoch, 3);
      // The position matters as much as the key: a joiner handed counter 0
      // could derive keys for messages sent before they arrived.
      expect(got.counter, 41);
      expect(got.chainKey, equals(chain));
      expect(got.issuedAtMs, 1700000000000);
    });

    test('never prints the key it carries', () {
      // Dart interpolates with toString(). A chain key in a log line is the
      // whole room, so this must stay redacted no matter who logs the object.
      final s = RoomKeyEventV1(
        roomId: 'group:r1',
        epoch: 1,
        counter: 0,
        chainKey: filled(32, 0xAB),
        issuedAtMs: 1,
      ).toString();
      expect(s, contains('redacted'));
      expect(s, isNot(contains(base64Encode(filled(32, 0xAB)))));
      expect(s, isNot(contains('qqqq')));
    });

    test('a key of the wrong length is refused, not stored', () {
      // Skipping the event costs one round trip (the member asks again with
      // gkeyreq). Accepting a bad key poisons the chain silently.
      for (final len in [0, 16, 31, 33, 64]) {
        expect(
          roundTrip(
            _RawEvent({
              'type': 'gkey',
              'room_id': 'group:r1',
              'epoch': 1,
              'counter': 0,
              'chain_key_b64': base64Encode(filled(len, 1)),
              'issued_at_ms': 1,
            }),
          ),
          isEmpty,
          reason: 'a $len-byte chain key must not parse',
        );
      }
    });

    test('malformed positions and rooms are refused', () {
      final bad = <Map<String, Object?>>[
        {'room_id': '', 'epoch': 1, 'counter': 0},
        {'room_id': '   ', 'epoch': 1, 'counter': 0},
        {'room_id': 'group:r1', 'epoch': -1, 'counter': 0},
        {'room_id': 'group:r1', 'epoch': 1, 'counter': -5},
        {'room_id': 'group:r1', 'epoch': 'three', 'counter': 0},
        {'room_id': 42, 'epoch': 1, 'counter': 0},
      ];
      for (final fields in bad) {
        expect(
          roundTrip(
            _RawEvent({
              'type': 'gkey',
              ...fields,
              'chain_key_b64': base64Encode(filled(32, 1)),
              'issued_at_ms': 1,
            }),
          ),
          isEmpty,
          reason: '$fields must not parse',
        );
      }
    });
  });

  group('gmsg', () {
    test('survives the wire', () {
      final nonce = filled(24, 7);
      final ct = filled(64, 9);
      final got =
          roundTrip(
                RoomMessageEventV1(
                  roomId: 'group:r1',
                  epoch: 2,
                  counter: 5,
                  nonce: nonce,
                  ciphertext: ct,
                ),
              ).single
              as RoomMessageEventV1;
      expect(got.roomId, 'group:r1');
      expect(got.epoch, 2);
      expect(got.counter, 5);
      expect(got.nonce, equals(nonce));
      expect(got.ciphertext, equals(ct));
    });

    test('a wrong-size nonce or a ciphertext too short for a tag is '
        'refused', () {
      Map<String, Object?> wire({int nonceLen = 24, int ctLen = 64}) => {
        'type': 'gmsg',
        'room_id': 'group:r1',
        'epoch': 1,
        'counter': 0,
        'nonce_b64': base64Encode(filled(nonceLen, 1)),
        'ciphertext_b64': base64Encode(filled(ctLen, 2)),
      };
      expect(roundTrip(_RawEvent(wire(nonceLen: 12))), isEmpty);
      expect(roundTrip(_RawEvent(wire(nonceLen: 32))), isEmpty);
      expect(roundTrip(_RawEvent(wire(ctLen: 15))), isEmpty);
      // A tag with an empty message is legitimate.
      expect(roundTrip(_RawEvent(wire(ctLen: 16))), hasLength(1));
    });
  });

  test('gkeyreq survives the wire', () {
    final got =
        roundTrip(RoomKeyRequestEventV1(roomId: 'group:r1', epoch: 4)).single
            as RoomKeyRequestEventV1;
    expect(got.roomId, 'group:r1');
    expect(got.epoch, 4);
  });

  test('an unrecognised type parses as unknown instead of throwing', () {
    // This is the MECHANISM the staged rollout leans on, not proof about a
    // specific old build: a client whose switch has no case for a type falls
    // through to UnknownEventV1 and stays inert. The released client reaches
    // `gkey`/`gmsg`/`gkeyreq` by exactly this branch, since its switch predates
    // them. (Proving it for the shipped binary needs the shipped binary — a
    // cross-version test, not a unit test.)
    for (final type in ['gkey_v2', 'gmsg_v2', 'gkeyreq_v2', 'not_a_type']) {
      expect(
        E2eEventV1.fromJson({'type': type, 'room_id': 'group:r1'}),
        isA<UnknownEventV1>(),
      );
    }
  });

  test('a bad room-key event does not take the rest of the payload with '
      'it', () {
    // decode() skips a single malformed event. A key that failed to parse must
    // not cost the user the message it was bundled with.
    final events = E2ePayloadV1.decode(
      E2ePayloadV1(
        senderDeviceId: 'devA',
        createdAtMs: 1000,
        events: [
          _RawEvent({
            'type': 'gkey',
            'room_id': 'group:r1',
            'epoch': 1,
            'counter': 0,
            'chain_key_b64': 'not base64 at all!!!',
            'issued_at_ms': 1,
          }),
          MsgEventV1(eventId: 'e1', text: 'привет'),
        ],
      ).encode(),
    ).events;

    expect(events, hasLength(1));
    expect((events.single as MsgEventV1).text, 'привет');
  });
}

/// Emits an arbitrary JSON shape so the tests can feed the parser wires a
/// well-behaved sender would never produce.
class _RawEvent extends E2eEventV1 {
  _RawEvent(this.json);

  final Map<String, Object?> json;

  @override
  Map<String, Object?> toJson() => json;
}
