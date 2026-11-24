// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Островок плеера закрывается сам, когда доиграло голосовое (23.11.2026).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

SharedAudioTrack _track(SharedAudioTrackKind kind) => SharedAudioTrack(
  trackId: 't',
  kind: kind,
  title: 'Голосовое сообщение',
  artist: 'Женя',
  resolveFilePath: () async => '/dev/null',
);

void main() {
  test('🔴 голосовое/аудио из чата доиграло — плеер закрывается', () {
    expect(
      sharedAudioClosesAtQueueEnd(_track(SharedAudioTrackKind.attachment)),
      isTrue,
    );
  });

  test('музыка профиля — остаётся на паузе, как раньше', () {
    expect(
      sharedAudioClosesAtQueueEnd(_track(SharedAudioTrackKind.profile)),
      isFalse,
    );
    expect(sharedAudioClosesAtQueueEnd(null), isFalse);
  });

  test('закрытие при конце очереди подключено к обработчику плеера', () {
    final src = File('lib/app/app_controller.dart').readAsStringSync();
    final i = src.indexOf('ProcessingState.completed');
    final handler = src.substring(i, i + 1600);
    expect(handler, contains('sharedAudioClosesAtQueueEnd('));
    expect(handler, contains('stopSharedAudio()'));
  });
}
