// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Очередь воспроизведения как в Telegram (21.11.2026): голосовые — только
// голосовые, музыка — только музыка, от старых к новым, без круга.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('lib/ui/chat_screen.dart').readAsStringSync();
  final load = src.substring(
    src.indexOf('  Future<List<_ChatAudioTrack>> _loadAudioQueue('),
    src.indexOf('  Future<_ResolvedMusicMetadata?> _resolveMusicMetadataForPlayback('),
  );

  test('🔴 очередь — по времени от старых к новым', () {
    expect(
      load.contains('..sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs))'),
      isTrue,
      reason: 'база отдаёт от новых — без сортировки голосовые шли назад',
    );
  });

  test('🔴 голосовые и музыка — разные очереди', () {
    expect(load.contains('if (voice != null && isVoice != voice) continue;'),
        isTrue);
    final start = src.substring(
      src.indexOf('  Future<void> _startAudioPlaybackFromAttachment('),
      src.indexOf('  SharedAudioTrack _sharedAudioTrackFromChatTrack('),
    );
    expect(start.contains('voice: _isVoiceMessageAttachment(attachment)'),
        isTrue);
    // Только что отправленное — в конец очереди, а не в начало.
    expect(start.contains('mutableQueue = [...queue, track];'), isTrue);
  });

  test('конец очереди — остановка, без круга', () {
    final ctl = File('lib/app/app_controller.dart').readAsStringSync();
    final h = ctl.substring(
      ctl.indexOf('  void _handleSharedAudioPlayerState(PlayerState state) {'),
    );
    final body = h.substring(0, h.indexOf('\n  }\n'));
    expect(body.contains('nextIndex < _sharedAudioQueue.length'), isTrue);
    expect(body.contains('_sharedAudioPlayer.pause()'), isTrue);
    expect(body.contains('index: 0'), isFalse,
        reason: 'возврат к первому треку — это и есть «круг»');
  });
}
