// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/platform_share_target.dart';

// 2026-07-23: sharing a screenshot into the app put a separate bubble with the
// filename next to the image, because many share sheets set EXTRA_SUBJECT to the
// file's name and the handler posted it as a message. meaningfulText drops a
// filename-only subject when files are present, but keeps a real caption.
void main() {
  PlatformSharePayload withImage(String? text, {String path = '/x/Screenshot_20260723_101530.png'}) =>
      PlatformSharePayload(
        files: [PlatformSharedFile(path: path, mime: 'image/png')],
        text: text,
      );

  test('a filename-only subject next to an image is dropped', () {
    expect(withImage('Screenshot_20260723_101530.png').meaningfulText, isNull);
    expect(withImage('Screenshot_20260723_101530').meaningfulText, isNull);
    expect(withImage('IMG_4821.jpg').meaningfulText, isNull);
    expect(withImage('photo.png').meaningfulText, isNull);
    expect(withImage('Снимок экрана 2026-07-23').meaningfulText, isNull);
  });

  test('the exact shared filename is dropped even without a known pattern', () {
    final p = PlatformSharePayload(
      files: [PlatformSharedFile(path: '/x/report-final.pdf', name: 'report-final.pdf')],
      text: 'report-final.pdf',
    );
    expect(p.meaningfulText, isNull);
  });

  test('a real caption typed by the person is kept', () {
    expect(withImage('смотри что нашёл!').meaningfulText, 'смотри что нашёл!');
    expect(withImage('check this out').meaningfulText, 'check this out');
  });

  test('a pure text share (no files) is never touched', () {
    const p = PlatformSharePayload(text: 'IMG_4821.jpg');
    expect(p.meaningfulText, 'IMG_4821.jpg',
        reason: 'without files there is nothing to disambiguate; forward as-is');
  });

  test('empty or whitespace text yields null', () {
    expect(withImage(null).meaningfulText, isNull);
    expect(withImage('   ').meaningfulText, isNull);
  });
}
