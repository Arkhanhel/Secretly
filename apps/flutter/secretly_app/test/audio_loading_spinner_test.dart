// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 21.11.2026, жалоба владельца на 704: голосовое уже звучит, а на кнопке
// крутится кружок загрузки. Причина: `play()` у just_audio завершается только
// когда звук встал, а кружок гас по завершении всего запуска — то есть в конце
// голосового. Теперь гаснет по первому «играет» именно этого трека.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat_screen.dart';

void main() {
  test('этот трек открыт и звучит — кружок гаснет', () {
    expect(
      audioLoadingShouldClear(
        loadingBlobId: 'b1',
        currentBlobId: 'b1',
        controllerLoading: false,
        playing: true,
      ),
      isTrue,
    );
  });

  test('плеер ещё открывает файл — кружок остаётся', () {
    expect(
      audioLoadingShouldClear(
        loadingBlobId: 'b1',
        currentBlobId: 'b1',
        controllerLoading: true,
        playing: false,
      ),
      isFalse,
    );
  });

  test('звучит другой трек — кружок этого не трогаем', () {
    expect(
      audioLoadingShouldClear(
        loadingBlobId: 'b1',
        currentBlobId: 'b0',
        controllerLoading: false,
        playing: true,
      ),
      isFalse,
    );
  });

  test('🔴 экран чата гасит кружок из слушателя плеера, а не после play()', () {
    final src = File('lib/ui/chat_screen.dart').readAsStringSync();
    final i = src.indexOf('void _handleSharedAudioPlaybackChanged()');
    final body = src.substring(i, i + 2600);
    expect(body.contains('audioLoadingShouldClear('), isTrue);
    expect(body.contains('_audioLoadingBlobId = null'), isTrue);
  });
}
