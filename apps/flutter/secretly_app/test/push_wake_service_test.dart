// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/push/push_wake_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('PushWakeService stores room-call wake hints from push metadata', () async {
    await PushWakeService.markWakeHint(<String, Object?>{
      'type': 'relay_pending',
      'wake_kind': 'room_call_sync_v1',
      'room_id': 'group:alpha',
      'call_id': 'call-1',
      'call_exists': 'true',
      'state_version': '5',
      'created_at_ms': '12345',
    });

    final snapshot = await PushWakeService.consumeWakeHint();
    expect(snapshot.hasWakeHint, isTrue);
    expect(snapshot.pending, isTrue);
    expect(snapshot.roomCallRoomIds, <String>['group:alpha']);
    expect(snapshot.roomCallHints, hasLength(1));
    expect(snapshot.roomCallHints.single.roomId, 'group:alpha');
    expect(snapshot.roomCallHints.single.callId, 'call-1');
    expect(snapshot.roomCallHints.single.callExists, isTrue);
    expect(snapshot.roomCallHints.single.stateVersion, 5);

    final consumedAgain = await PushWakeService.consumeWakeHint();
    expect(consumedAgain.hasWakeHint, isFalse);
    expect(consumedAgain.roomCallHints, isEmpty);
  });

  test('PushWakeService stores recent message wake timestamps by msg id', () async {
    await PushWakeService.markWakeHint(<String, Object?>{
      'type': 'relay_pending',
      'msg_id': 'msg-42',
    });

    final wakeReceivedAtMs = await PushWakeService.recentMessageWakeReceivedAtMs(
      'msg-42',
      reloadPrefs: false,
    );

    expect(wakeReceivedAtMs, isNotNull);
    expect(wakeReceivedAtMs, greaterThan(0));
    expect(
      await PushWakeService.recentMessageWakeReceivedAtMs(
        'missing-msg',
        reloadPrefs: false,
      ),
      isNull,
    );
  });

  test('PushWakeService stores opened conversation ids from tapped notifications', () async {
    await PushWakeService.markOpenedConversationForTesting(<String, Object?>{
      'convo_id': 'group:opened-room',
    });

    final openedConvoId = await PushWakeService.consumeOpenedConversationId();
    expect(openedConvoId, 'group:opened-room');
    expect(await PushWakeService.consumeOpenedConversationId(), isNull);
  });
}