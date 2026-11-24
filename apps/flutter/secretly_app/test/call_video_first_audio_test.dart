// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 21.11.2026, жалоба владельца: «звонишь голосовым и переключаешься на видео
// — всё слышно; звонишь сразу видеозвонком — не слышно никого».
//
// Звуковая часть у обоих путей одинакова. Различалось одно: у видеозвонка
// громкая включалась ДО того, как система подняла звук звонка (при создании
// соединения, при приёме, в самом соединении, маршрутом «громкая по
// умолчанию»). Рабочий путь «голосовой → видео» включает громкую уже в живом
// звонке. Второе: звонящий ждал видео, которого принявший с выключенной
// камерой не шлёт, — «нет кадров» запускало перезапуски и обрыв.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manager = File('lib/calls/call_manager.dart').readAsStringSync();
  final session = File('lib/calls/webrtc_call_session.dart').readAsStringSync();

  String body(String src, String signature, {int span = 4000}) {
    final at = src.indexOf(signature);
    expect(at, greaterThan(0), reason: signature);
    return src.substring(at, (at + span).clamp(0, src.length));
  }

  test('🔴 соединение само громкую не включает, если ей владеет менеджер', () {
    final out = body(session, 'Future<void> startOutgoing({', span: 900);
    expect(out.contains('if (!speakerOwnedByManager) {'), isTrue);
    final inc = body(
      session,
      'Future<void> startIncomingFromOffer({',
      span: 9000,
    );
    expect(
      inc.contains(
        'if (!speakerOwnedByManager) {\n'
        '      _speakerEnabled = video || remoteOffersSendingVideo;',
      ),
      isTrue,
    );
  });

  test('🔴 менеджер владеет громкой; до соединения — трубка', () {
    expect(manager.contains('session.speakerOwnedByManager = true;'), isTrue);
    final apply = body(manager, 'Future<void> _applySpeakerPreference(');
    expect(apply.contains('final enabled = connected && s.isSpeaker;'), isTrue);
    // Приём больше не включает громкую напрямую.
    expect(manager.contains('await session.setSpeakerEnabled(s.isVideo);'),
        isFalse);
    expect(
      manager.contains('await session.setSpeakerEnabled(state.value.isSpeaker);'),
      isFalse,
    );
  });

  test('🔴 «громкая по умолчанию» у маршрутов — только после соединения', () {
    final sync = body(manager, 'Future<void> _syncAudioRoutesForCurrentCall({',
        span: 700);
    expect(sync.contains('preferSpeakerByDefault: current.isVideo && connected'),
        isTrue);
  });

  test('соединился — желание «громкая» исполняется путём кнопки', () {
    final connected = body(
      manager,
      'void _markConnectedFromSession({required String source}) {',
      span: 2600,
    );
    expect(connected.contains('_applySpeakerOnConnect()'), isTrue);
    final onConnect = body(manager, 'Future<void> _applySpeakerOnConnect()');
    // Выбор делает приложение, а не человек (22.11.2026): наушники,
    // подключённые позже, по-прежнему перехватывают звук.
    expect(
      onConnect.contains('selectAudioRoute(speaker.deviceId, byUser: false)'),
      isTrue,
    );
    expect(onConnect.contains('if (external) return;'), isTrue,
        reason: 'наушники и Bluetooth важнее громкой');
    // Видеозвонок помнит желание с начала.
    expect(manager.contains('_speakerWantedOnConnect = video;'), isTrue);
    expect(manager.contains('_speakerWantedOnConnect = state.value.isVideo;'),
        isTrue);
  });

  test('нажатие громкой до соединения — желание, а не переключение', () {
    final toggle = body(manager, 'Future<void> toggleSpeaker() async {',
        span: 900);
    expect(toggle.contains('before.connectedAtMs == null'), isTrue);
    expect(toggle.contains('_speakerWantedOnConnect = next;'), isTrue);
  });

  test('переход на видео в живом звонке включает громкую на деле', () {
    final upgrade = body(manager, 'Future<void> upgradeToVideo() async {',
        span: 4000);
    expect(upgrade.contains('await _applySpeakerOnConnect();'), isTrue);
  });

  test('🔴 ответ без видео снимает ожидание видео (нет лестницы обрыва)', () {
    final answer = body(session, 'Future<void> applyRemoteAnswer(', span: 4200);
    expect(
      answer.contains(
        '} else if (_expectsRemoteVideo && !answerSendsVideo) {',
      ),
      isTrue,
    );
    expect(answer.contains('_setRemoteVideoExpectation(false);'), isTrue);
  });
}
