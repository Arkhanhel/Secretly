// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Подпись альбома — с любого снимка (24.11.2026).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/album_caption.dart';

void main() {
  test('подпись не первого снимка становится подписью альбома', () {
    expect(albumCaptionOf(['', null, 'Клада да']), 'Клада да');
    expect(albumCaptionOf(['  Первая ', '', 'Третья']), 'Первая\nТретья');
    expect(albumCaptionOf(['одна', 'одна']), 'одна');
    expect(albumCaptionOf(['', ' ', null]), isNull);
    expect(albumCaptionOf(const <String?>[]), isNull);
  });

  test('🔴 пузырь альбома и отправка берут подпись со всех снимков', () {
    final ui = File('lib/ui/chat_screen.dart').readAsStringSync();
    expect(ui.contains('attachments.first.caption'), isFalse);
    expect(ui.contains('items.first.caption'), isFalse);
    expect(
      ui.contains('albumCaptionOf(attachments.map((e) => e.caption))'),
      isTrue,
    );
    final c = File('lib/app/app_controller.dart').readAsStringSync();
    expect(c.contains('album.items.first.caption'), isFalse);
    expect(c.contains('batch.items.first.caption'), isFalse);
  });
}
