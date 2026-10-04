// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 УВЕДОМЛЕНИЯ И ЗАМКИ, УВЕДОМЛЕНИЯ И ПОКАЗ ЭКРАНА (30.09.2026).
//
// * Замки уведомлений не касались: у запертого компьютера баннер называл
//   отправителя, показывал текст, а «Ответить» отправляло сообщение — в том
//   числе с компьютера, запертого как потерянный.
// * Защита «при показе экрана уведомления молчат» была, но включать её было
//   нечему: имена и текст попадали в показ.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/call_state.dart';
import 'package:secretly_app/rooms/room_call_media_state.dart';
import 'package:secretly_app/ui/desktop/services/desktop_notification_service.dart';

RoomCallParticipantRuntimeState _participant({
  required bool self,
  required bool sharing,
}) => RoomCallParticipantRuntimeState(
  profileId: self ? 'me' : 'peer',
  deviceId: self ? 'me-dev' : 'peer-dev',
  joinState: 'joined',
  isSelf: self,
  publishAudio: true,
  publishVideo: false,
  publishScreenShare: sharing,
  receiveAudio: true,
  receiveVideo: true,
  receiveScreenShare: true,
  kind: RoomCallParticipantRuntimeKind.audioOnly,
  errorMessage: null,
  updatedAtMs: 0,
);

RoomCallRuntimeState _room({
  bool active = true,
  bool localScreen = false,
  List<RoomCallParticipantRuntimeState> participants = const [],
}) => RoomCallRuntimeState(
  phase: active
      ? RoomCallRuntimePhase.bootstrapReady
      : RoomCallRuntimePhase.idle,
  roomId: 'group:r1',
  callId: 'c1',
  stateVersion: 1,
  lastSyncedAtMs: 0,
  session: null,
  localMedia: localScreen
      ? const RoomCallLocalMediaState.idle().copyWith(screenShareActive: true)
      : const RoomCallLocalMediaState.idle(),
  participants: participants,
  errorMessage: null,
);

void main() {
  group('уровень показа под замком', () {
    test('🔴 заперто — ни отправителя, ни текста', () {
      for (final level in const [0, 1, 2]) {
        expect(
          desktopEffectivePreviewLevel(previewLevel: level, locked: true),
          0,
        );
      }
    });

    test('🔴 личная переписка при запертых «Личных» — тоже уровень 0', () {
      expect(
        desktopEffectivePreviewLevel(
          previewLevel: 2,
          locked: false,
          personalHidden: true,
        ),
        0,
      );
    });

    test('не заперто — уровень человека, как был', () {
      for (final level in const [0, 1, 2]) {
        expect(
          desktopEffectivePreviewLevel(previewLevel: level, locked: false),
          level,
        );
      }
      expect(desktopEffectivePreviewLevel(previewLevel: 7, locked: false), 2);
    });

    test('🔴 под замком у баннера нет кнопок «Ответить» и «Прочитано»', () {
      final level = desktopEffectivePreviewLevel(previewLevel: 2, locked: true);
      expect(
        notificationActionsAllowed(previewLevel: level, convoId: 'P-1'),
        isFalse,
      );
    });

    test('🔴 входящий звонок под замком не называет звонящего', () {
      expect(
        desktopCallNotificationBody(
          previewLevel: desktopEffectivePreviewLevel(
            previewLevel: 2,
            locked: true,
          ),
          knownName: 'Игорь',
          appTitle: 'Secretly',
        ),
        'Secretly',
      );
    });
  });

  group('показ экрана', () {
    test('звонок один на один: показ идёт', () {
      expect(
        desktopScreenShareActive(
          direct: CallState(phase: CallPhase.connected, isScreenSharing: true),
        ),
        isTrue,
      );
    });

    test('закончившийся звонок показа не держит', () {
      expect(
        desktopScreenShareActive(
          direct: CallState(phase: CallPhase.ended, isScreenSharing: true),
        ),
        isFalse,
      );
      expect(desktopScreenShareActive(), isFalse);
    });

    test('созвон комнаты: показ моего экрана', () {
      expect(desktopScreenShareActive(room: _room(localScreen: true)), isTrue);
      expect(
        desktopScreenShareActive(
          room: _room(participants: [_participant(self: true, sharing: true)]),
        ),
        isTrue,
      );
    });

    test('чужой показ в комнате — не мой', () {
      expect(
        desktopScreenShareActive(
          room: _room(participants: [_participant(self: false, sharing: true)]),
        ),
        isFalse,
      );
      expect(
        desktopScreenShareActive(room: _room(active: false, localScreen: true)),
        isFalse,
      );
    });
  });

  group('проводка', () {
    final service = File(
      'lib/ui/desktop/services/desktop_notification_service.dart',
    ).readAsStringSync();
    final app = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();

    String body(String src, String start) {
      final from = src.indexOf(start);
      expect(from, greaterThanOrEqualTo(0), reason: start);
      return src.substring(from, src.indexOf('\n  }\n', from));
    }

    test('🔴 ответ и «прочитано» из уведомления под замком не уходят', () {
      expect(
        body(
          service,
          '  Future<void> _sendReply(',
        ).contains('if (_actionsBlocked(convoId)) return;'),
        isTrue,
      );
      expect(
        body(
          service,
          '  Future<void> _markRead(',
        ).contains('if (_actionsBlocked(convoId)) return;'),
        isTrue,
      );
    });

    test('сообщения и звонки считают уровень с учётом замков', () {
      expect(
        body(
          service,
          '  Future<void> _onChatEvent(',
        ).contains('desktopEffectivePreviewLevel('),
        isTrue,
      );
      expect(
        body(
          service,
          '  void _onCallStateChanged(',
        ).contains('desktopEffectivePreviewLevel('),
        isTrue,
      );
    });

    test('корень подаёт замки и показ экрана службе', () {
      expect(app.contains('svc.lockEngaged = () => _anyLockEngaged;'), isTrue);
      expect(app.contains('svc.personalHidden = (convoId) =>'), isTrue);
      expect(
        app.contains('rcm.state.addListener(_syncScreenShareGuard);'),
        isTrue,
      );
      expect(
        body(
          app,
          '  void _onCallStateChanged() {',
        ).contains('_syncScreenShareGuard();'),
        isTrue,
      );
      expect(
        body(
          app,
          '  void _syncScreenShareGuard() {',
        ).contains('setScreenShareActive(on)'),
        isTrue,
      );
    });

    test('🔴 нажатие на уведомление под замком только выводит окно', () {
      final tap = body(app, '  void _onNotificationTap(String payload) {');
      final guard = tap.indexOf('_anyLockEngaged');
      final open = tap.indexOf('_openConvoOrReport(convoId)');
      expect(guard, greaterThan(0));
      expect(open, greaterThan(guard));
    });
  });
}
