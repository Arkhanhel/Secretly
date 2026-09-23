// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

/// Receive side of the room sender key (фаза 3).
///
/// Shipping order matters here: the receive side lands BEFORE the send side,
/// because a client has to be able to read the new format before any client
/// emits it — the other order loses the first message of every room that
/// upgrades. Until the flag is flipped this whole path is inert, and a wire
/// that arrives anyway is PARKED rather than acknowledged away.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('room sender key flags — SEND and RECEIVE are separate', () {
    tearDown(() {
      AppController.roomSenderKeySendEnabled = false;
      AppController.roomSenderKeyReceiveEnabled = true;
    });

    test('SEND ships OFF — the new format changes nothing until flipped', () {
      expect(AppController.roomSenderKeySendEnabled, isFalse);
    });

    test('SEND is switchable for a staged rollout', () {
      AppController.roomSenderKeySendEnabled = true;
      expect(AppController.roomSenderKeySendEnabled, isTrue);
      AppController.roomSenderKeySendEnabled = false;
      expect(AppController.roomSenderKeySendEnabled, isFalse);
    });

    test(
      'RECEIVE ships ON — a build that can read `gmsg` always reads it',
      () {
        // 🔴 THE FIELD LOSS THIS ENCODES (1.7.4+416): one flag gated seal, open
        // and `gkeyreq` together, so a device holding the receive code refused
        // to use it merely because it was not itself a sender. It parked the
        // wire, exhausted its retries, ACKed it, and the message was gone.
        // Receive must never be hostage to the send rollout.
        expect(AppController.roomSenderKeyReceiveEnabled, isTrue);
      },
    );

    test(
      'REGRESSION: turning SEND off must not turn RECEIVE off with it',
      () {
        AppController.roomSenderKeySendEnabled = false;
        expect(
          AppController.roomSenderKeyReceiveEnabled,
          isTrue,
          reason: 'a non-sender still has to be able to READ room wires',
        );
      },
    );

    test('the two flags are genuinely independent in both directions', () {
      AppController.roomSenderKeySendEnabled = true;
      AppController.roomSenderKeyReceiveEnabled = false;
      expect(AppController.roomSenderKeySendEnabled, isTrue);
      expect(AppController.roomSenderKeyReceiveEnabled, isFalse);

      AppController.roomSenderKeySendEnabled = false;
      AppController.roomSenderKeyReceiveEnabled = true;
      expect(AppController.roomSenderKeySendEnabled, isFalse);
      expect(AppController.roomSenderKeyReceiveEnabled, isTrue);
    });
  });

  group('acknowledge or park — the rule that decides message loss', () {
    // Both directions are expensive. Acknowledging a wire we could still open
    // loses the message PERMANENTLY: the relay drops it and nothing brings it
    // back. Parking one we can never open replays it forever.

    test('a wire we might still open is PARKED', () {
      // The key can still arrive — `gkeyreq` exists to ask for it.
      expect(
        AppController.roomWireShouldPark(RoomWireOutcome.noKeyYet),
        isTrue,
      );
      // The message inside failed to apply for some other reason; a later
      // attempt may succeed.
      expect(
        AppController.roomWireShouldPark(RoomWireOutcome.innerNotApplied),
        isTrue,
      );
      // Local storage hiccup says nothing about the wire.
      expect(
        AppController.roomWireShouldPark(RoomWireOutcome.storeError),
        isTrue,
      );
    });

    test('a wire we can NEVER open is acknowledged, not replayed', () {
      // The tag failed: wrong room, generation, position or tampered. A replay
      // fails identically, so parking it would loop forever.
      expect(
        AppController.roomWireShouldPark(RoomWireOutcome.tagFailed),
        isFalse,
      );
      // Authentic but unparseable — no replay will make it parse.
      expect(
        AppController.roomWireShouldPark(RoomWireOutcome.innerMalformed),
        isFalse,
      );
      // A room envelope inside a room envelope: refusing to recurse must not
      // turn into refusing to ever finish.
      expect(AppController.roomWireShouldPark(RoomWireOutcome.nested), isFalse);
      // Nothing to attribute it to; a replay cannot invent a sender.
      expect(
        AppController.roomWireShouldPark(RoomWireOutcome.noSender),
        isFalse,
      );
    });

    test('a wire that WAS applied is never parked', () {
      expect(AppController.roomWireShouldPark(RoomWireOutcome.applied), isFalse);
    });

    test('every outcome has a decision — a new one cannot slip through', () {
      // The switch is exhaustive by construction; this fails to compile rather
      // than silently defaulting if an outcome is ever added.
      for (final outcome in RoomWireOutcome.values) {
        expect(AppController.roomWireShouldPark(outcome), isA<bool>());
      }
    });
  });

  group('a key must outlive an offline member', () {
    test('the key ttl is the MESSAGE ttl, not the control ttl', () {
      // Caught on review, not by a failure: a key sent at the control ttl (1
      // hour) expires while the messages it protects sit in the mailbox for a
      // week. A member offline for an hour would lose the key and the room
      // would simply stop working for them. The relay retains mailboxes for 7
      // days, so the key must live exactly as long as anything it can open.
      expect(
        AppController.roomKeyGrantTtlSeconds,
        AppController.outboxUserMessageTtlSeconds,
      );
      expect(
        AppController.roomKeyGrantTtlSeconds,
        greaterThan(AppController.controlMessageTtlSeconds),
      );
      expect(AppController.roomKeyGrantTtlSeconds, 7 * 24 * 60 * 60);
    });
  });

  group('gkeyreq recovery — asking without shouting', () {
    test('a member does not ask on the FIRST miss', () {
      // The key and the message travel over two different pairwise sessions and
      // routinely overtake each other. Asking on the first miss would turn
      // every ordinary race into a burst of requests across the whole room.
      expect(AppController.roomKeyRequestThreshold, greaterThan(1));
      // Small enough that a genuinely unkeyed member recovers in seconds, not
      // never. Mirrors the pairwise NACK threshold.
      expect(AppController.roomKeyRequestThreshold, 3);
    });

    test('a second ask waits long enough for the first answer to be used', () {
      // The answer has to travel, be applied and be used before asking again
      // means anything; anything shorter just multiplies traffic.
      expect(
        AppController.roomKeyRequestDebounceMs,
        greaterThanOrEqualTo(60 * 1000),
      );
      expect(AppController.roomKeyRequestDebounceMs, 5 * 60 * 1000);
    });

    test('the author answers faster than the member re-asks', () {
      // Otherwise a member could ask again before the previous answer was even
      // allowed to be sent, and the pair would sit in lockstep. Re-issuing is
      // idempotent, so the author may be the more eager side.
      expect(
        AppController.roomKeyReissueDebounceMs,
        lessThan(AppController.roomKeyRequestDebounceMs),
      );
    });
  });
}
