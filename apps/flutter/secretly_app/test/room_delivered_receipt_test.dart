// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/messages/message_delivery_state.dart';
import 'package:secretly_app/storage/app_db.dart';

/// Per-member delivery evidence in rooms (2026-07-30).
///
/// Until this change a room emitted NO `delivered` receipt — only `read`, and
/// only when the user opened the room. Two consequences, both silent:
///  * the author could not tell that nine of ten members never got a message;
///  * the room convergence backstop looks for exactly this evidence, so its
///    absence proved nothing and switching the backstop on would have reset
///    sessions at healthy rooms nobody had opened yet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('who owes the author a delivered receipt', () {
    bool owes({
      bool isOwnSend = false,
      String kind = 'text',
      String senderDeviceId = 'peer-dev',
      String payloadEventId = 'p1',
    }) => AppController.shouldSendRoomDeliveredReceipt(
      isOwnSend: isOwnSend,
      kind: kind,
      senderDeviceId: senderDeviceId,
      payloadEventId: payloadEventId,
    );

    test('an ordinary room message from another member does', () {
      for (final kind in ['text', 'attachment', 'sticker']) {
        expect(owes(kind: kind), isTrue, reason: kind);
      }
    });

    test('my own message arriving via self-mirror does not', () {
      // Acknowledging my own message to myself is pure noise, and it would make
      // every room look like it had delivery evidence it does not have.
      expect(owes(isOwnSend: true), isFalse);
    });

    test('a system frame does not', () {
      // Joins and renames are not user messages; receipting them would turn
      // membership churn into receipt traffic.
      expect(owes(kind: 'system'), isFalse);
    });

    test('a frame with nobody to answer, or nothing to reference, does not', () {
      expect(owes(senderDeviceId: ''), isFalse);
      expect(owes(senderDeviceId: '   '), isFalse);
      expect(owes(payloadEventId: ''), isFalse);
      expect(owes(payloadEventId: '  '), isFalse);
    });
  });

  test('a delivered receipt is what clears a member from the backstop\'s '
      'sights', () async {
    // The end-to-end point of the change: before the receipt the member owes
    // the message and the backstop would repair them; after it, they do not.
    final db = await AppDb.openForTesting();
    final now = DateTime.now().millisecondsSinceEpoch;
    final old = now - 5 * 60 * 1000;

    await db.insertEvent(
      eventId: 'm1',
      convoId: 'group:team',
      type: 'msg',
      senderDeviceId: 'my-dev',
      ciphertextB64: 'x',
      createdAtMs: old,
      localState: 'sent',
      payloadEventId: 'p1',
    );

    Future<bool> owedTo(String reader) async => (await db
            .roomSendsMissingReceiptFrom(
              roomId: 'group:team',
              readerProfileId: reader,
              senderDeviceId: 'my-dev',
              stuckBeforeMs: now - 90 * 1000,
            ))
        .isNotEmpty;

    expect(await owedTo('bob'), isTrue);

    await db.roomMessageReceiptUpsert(
      payloadEventId: 'p1',
      readerProfileId: 'bob',
      readerDeviceId: 'bob-dev',
      status: MessageReceiptState.delivered,
      updatedAtMs: now,
    );

    expect(
      await owedTo('bob'),
      isFalse,
      reason: 'a delivered receipt must clear the debt, not only a read one',
    );
    // A different member who never acknowledged is still owed it — the
    // evidence is per member, which is the entire point.
    expect(await owedTo('carol'), isTrue);

    await db.close();
  });

  test('a member on an older build is never judged by receipts they cannot '
      'send', () async {
    // Builds before 2026-07-30 emit no room receipts at all. During the
    // rollout "no receipt from them" is the norm, not a fault — reading it as
    // one would re-key every member still on an older version, on a loop.
    final db = await AppDb.openForTesting();

    expect(
      await db.roomReceiptEverFrom(readerProfileId: 'old-build-member'),
      isFalse,
    );

    // One acknowledgement anywhere is enough to prove the build acks at all;
    // from then on their silence in a room IS meaningful.
    await db.roomMessageReceiptUpsert(
      payloadEventId: 'p-elsewhere',
      readerProfileId: 'new-build-member',
      readerDeviceId: 'nb-dev',
      status: MessageReceiptState.delivered,
      updatedAtMs: 1,
    );
    expect(
      await db.roomReceiptEverFrom(readerProfileId: 'new-build-member'),
      isTrue,
    );
    // Not confused between members.
    expect(
      await db.roomReceiptEverFrom(readerProfileId: 'old-build-member'),
      isFalse,
    );
    expect(await db.roomReceiptEverFrom(readerProfileId: '  '), isFalse);

    await db.close();
  });
}
