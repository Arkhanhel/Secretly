// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ignore_for_file: experimental_member_use
// 15.11.2026: громкая связь на iPhone в личном звонке. LiveKit 2.13.1 забирал
// звуковую сессию у всех звонков; на время личного звонка — режим manual,
// после — automatic.
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:secretly_app/calls/call_state.dart';
import 'package:secretly_app/calls/livekit_audio_session_guard.dart';

void main() {
  CallState at(CallPhase p) => CallState(phase: p);

  test('iPhone: звонок — manual, конец — automatic, без лишних вызовов', () async {
    final calls = <lk.AudioSessionManagementMode>[];
    final guard = LiveKitAudioSessionGuard(
      setMode: (m) async => calls.add(m),
      isApple: true,
    );
    guard.onCallState(at(CallPhase.idle));
    expect(calls, isEmpty);
    guard.onCallState(at(CallPhase.ringingOutgoing));
    guard.onCallState(at(CallPhase.connecting));
    guard.onCallState(at(CallPhase.connected));
    expect(calls, [lk.AudioSessionManagementMode.manual]);
    expect(guard.isManual, isTrue);
    guard.onCallState(at(CallPhase.ended));
    guard.onCallState(at(CallPhase.idle));
    expect(calls, [
      lk.AudioSessionManagementMode.manual,
      lk.AudioSessionManagementMode.automatic,
    ]);
    // Входящий — тоже личный звонок.
    guard.onCallState(at(CallPhase.ringingIncoming));
    expect(calls.last, lk.AudioSessionManagementMode.manual);
  });

  test('не iPhone — режим LiveKit не трогаем', () {
    final calls = <lk.AudioSessionManagementMode>[];
    final guard = LiveKitAudioSessionGuard(
      setMode: (m) async => calls.add(m),
      isApple: false,
    );
    guard.onCallState(at(CallPhase.connected));
    guard.onCallState(at(CallPhase.idle));
    expect(calls, isEmpty);
  });

  test('сбой переключения не роняет звонок', () async {
    final guard = LiveKitAudioSessionGuard(
      setMode: (m) async => throw StateError('нет канала'),
      isApple: true,
    );
    guard.onCallState(at(CallPhase.connected));
    await Future<void>.delayed(Duration.zero);
    expect(guard.isManual, isTrue);
  });
}
