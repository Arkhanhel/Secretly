// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/entitlements/entitlement_signature.dart';
import 'package:secretly_app/messages/room_flags.dart';

/// Server-signed SEND kill-switch for the room sender key (F-ROOMSK-2).
///
/// The block exists because 1.7.4+416 shipped a build sealing room messages a
/// peer could not read: the wires were ACKed and the messages lost for good,
/// and with a compile-time flag the only remedy was reinstalling the app.
void main() {
  group('roomsSigningMessage — contract with the Rust server', () {
    test('is byte-stable', () {
      // MUST match `rooms_signing_message` in server/keys/src/main.rs exactly.
      // A divergence does not fail loudly — it makes every signature
      // unverifiable, and this block fails OFF, so sending would quietly stop.
      expect(
        roomsSigningMessage(senderKeySendEnabled: true, issuedAtMs: 42),
        'secretly-rooms-v1|true|42',
      );
      expect(
        roomsSigningMessage(senderKeySendEnabled: false, issuedAtMs: 7),
        'secretly-rooms-v1|false|7',
      );
    });
  });

  group('effectiveRoomSenderKeySend — BOTH keys, and unresolved means NO', () {
    // 🔴 Caught during the pre-build check, not by a test: the controller used
    // to seed its flag from the BUILD flag and then `return` early when the
    // server block was unresolved. A flag-on build therefore sealed room
    // messages during every window where the config could not be fetched — no
    // network, a 429, an old server, a failed signature — which is exactly the
    // unauthorised sending the kill-switch exists to prevent.

    test('both keys yes ⇒ sending permitted', () {
      expect(
        AppController.effectiveRoomSenderKeySend(
          builtWith: true,
          serverResolved: true,
          serverAllows: true,
        ),
        isTrue,
      );
    });

    test('REGRESSION: unresolved server block is a NO, not "keep going"', () {
      expect(
        AppController.effectiveRoomSenderKeySend(
          builtWith: true,
          serverResolved: false,
          serverAllows: true,
        ),
        isFalse,
      );
    });

    test('the server can kill a build that WAS built for it', () {
      expect(
        AppController.effectiveRoomSenderKeySend(
          builtWith: true,
          serverResolved: true,
          serverAllows: false,
        ),
        isFalse,
      );
    });

    test('the server can never enable a build that was not built for it', () {
      expect(
        AppController.effectiveRoomSenderKeySend(
          builtWith: false,
          serverResolved: true,
          serverAllows: true,
        ),
        isFalse,
      );
    });

    test('the shipped default is dormant', () {
      // Not seeded from the build flag: see the field above.
      expect(AppController.roomSenderKeySendEnabled, isFalse);
    });
  });

  group('RoomFlags — failure direction is OFF', () {
    test('defaults leave SENDING dormant', () {
      expect(RoomFlags.defaults.senderKeySendEnabled, isFalse);
    });

    test('an UNVERIFIED block never enables sending', () {
      // The whole point: nothing unauthenticated may switch on a wire format
      // whose failure mode is silent, permanent loss on the RECIPIENT.
      final flags = RoomFlags.fromConfigResponse(
        <String, dynamic>{
          'rooms': <String, dynamic>{'sender_key_send_enabled': true},
        },
        verified: false,
      );
      expect(flags.senderKeySendEnabled, isFalse);
    });

    test('a missing block leaves sending dormant', () {
      final flags = RoomFlags.fromConfigResponse(
        <String, dynamic>{},
        verified: true,
      );
      expect(flags.senderKeySendEnabled, isFalse);
    });

    test('a garbage block leaves sending dormant', () {
      final flags = RoomFlags.fromConfigResponse(
        <String, dynamic>{'rooms': 'not-a-map'},
        verified: true,
      );
      expect(flags.senderKeySendEnabled, isFalse);
    });

    test('only a VERIFIED block that says true permits sending', () {
      final flags = RoomFlags.fromConfigResponse(
        <String, dynamic>{
          'rooms': <String, dynamic>{'sender_key_send_enabled': true},
        },
        verified: true,
      );
      expect(flags.senderKeySendEnabled, isTrue);
    });

    test('a verified block CAN kill sending', () {
      // The lever we did not have on 1.7.4+416.
      final flags = RoomFlags.fromConfigResponse(
        <String, dynamic>{
          'rooms': <String, dynamic>{'sender_key_send_enabled': false},
        },
        verified: true,
      );
      expect(flags.senderKeySendEnabled, isFalse);
    });

    test('a non-boolean value is not truthy', () {
      final flags = RoomFlags.fromConfigResponse(
        <String, dynamic>{
          'rooms': <String, dynamic>{'sender_key_send_enabled': 'true'},
        },
        verified: true,
      );
      expect(flags.senderKeySendEnabled, isFalse);
    });
  });
}
