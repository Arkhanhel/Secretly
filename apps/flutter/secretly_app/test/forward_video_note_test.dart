// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/pending_attachment_upload.dart';

// 🔴 K-a (17.09.2026): пересланный «кружок» уходил обычным видео.
//
// Признак не доходил ни до задания очереди, ни до отправки, а очередь ещё и
// пересжимала его как видео. Исходная отправка кружка (`_sendVideoNote`)
// кладёт `videoNote: true` и не пережимает.

String _block(String src, String start, String end) {
  final from = src.indexOf(start);
  expect(from, isNot(-1), reason: start);
  final to = src.indexOf(end, from + start.length);
  expect(to, isNot(-1), reason: end);
  return src.substring(from, to);
}

void main() {
  test('задание очереди несёт признак, по умолчанию — нет', () {
    PendingPhotoUpload upload({bool? videoNote}) => videoNote == null
        ? PendingPhotoUpload(
            id: '1',
            filePath: '/tmp/x.mp4',
            mime: 'video/mp4',
            caption: '',
            totalBytes: 1,
          )
        : PendingPhotoUpload(
            id: '1',
            filePath: '/tmp/x.mp4',
            mime: 'video/mp4',
            caption: '',
            totalBytes: 1,
            videoNote: videoNote,
          );
    expect(upload().videoNote, isFalse);
    expect(upload(videoNote: true).videoNote, isTrue);
  });

  test('🔴 очередь передаёт признак в обе отправки и не пережимает кружок', () {
    final src = File('lib/app/app_controller.dart').readAsStringSync();
    final runner = _block(
      src,
      '  Future<void> _runPendingPhotoUpload(PendingPhotoUpload pending)',
      '      pending.payloadEventId = payloadEventId;',
    );
    expect(
      'videoNote: pending.videoNote,'.allMatchesIn(runner),
      2,
      reason: 'и в комнату, и в личный чат',
    );
    expect(runner.contains('!pending.videoNote &&'), isTrue);
  });

  test('🔴 пересылка с телефона берёт признак из исходного сообщения', () {
    final src = File('lib/ui/chat_screen.dart').readAsStringSync();
    final forward = _block(
      src,
      '  Future<void> _enqueueForwardAttachment({',
      '  Future<void> _shareSingleAttachment({',
    );
    expect(forward.contains('videoNote: event.videoNote,'), isTrue);
  });

  test('🔴 пересылка с компьютера — тоже, в обе стороны', () {
    final src = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();
    final forward = _block(
      src,
      '  Future<_CopyOutcome> _sendForwardedCopy(',
      '  /// Файл вложения на диске: готовый из ленты или скачанный сейчас.',
    );
    expect('videoNote: attachment.videoNote,'.allMatchesIn(forward), 2);
  });
}

extension on String {
  int allMatchesIn(String haystack) => allMatches(haystack).length;
}
