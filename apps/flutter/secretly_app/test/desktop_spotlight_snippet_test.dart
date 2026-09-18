// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ui/desktop/app/desktop_spotlight.dart';

/// F-04 — the snippet shown for a global message hit.
///
/// This is pure index arithmetic over user text, which is exactly where it
/// breaks: a match at the very start or very end of a long message used to be
/// able to push the window past the end of the string.
void main() {
  test('a short message is shown whole, with no ellipsis', () {
    expect(spotlightSnippet('привет', 0), 'привет');
  });

  test('collapses newlines and runs of whitespace', () {
    expect(spotlightSnippet('привет\n\n   мир', 0), 'привет мир');
  });

  test('empty or whitespace-only text yields nothing to show', () {
    expect(spotlightSnippet('', 0), '');
    expect(spotlightSnippet('   \n  ', 0), '');
  });

  test('a match at the very start does not prepend an ellipsis', () {
    final text = 'начало ${'x' * 200}';
    final s = spotlightSnippet(text, 0);
    expect(s.startsWith('…'), isFalse);
    expect(s.endsWith('…'), isTrue);
    expect(s, contains('начало'));
  });

  test('a match at the very end stays inside the string', () {
    final text = '${'x' * 200} конец';
    final s = spotlightSnippet(text, text.length - 5);
    expect(s.startsWith('…'), isTrue);
    // The window must clamp to the end rather than overrun it — this is the
    // case that would previously throw a RangeError.
    expect(s.endsWith('…'), isFalse);
    expect(s, contains('конец'));
  });

  test('a match in the middle is shown with context on both sides', () {
    final text = '${'a' * 100}ИСКОМОЕ${'b' * 100}';
    final s = spotlightSnippet(text, 100);
    expect(s.startsWith('…'), isTrue);
    expect(s.endsWith('…'), isTrue);
    expect(s, contains('ИСКОМОЕ'));
  });

  test('an out-of-range match index does not throw', () {
    final text = 'x' * 200;
    expect(() => spotlightSnippet(text, 100000), returnsNormally);
    expect(() => spotlightSnippet(text, -50), returnsNormally);
  });

  test('the result never exceeds the window plus its ellipses', () {
    final text = 'y' * 500;
    expect(spotlightSnippet(text, 250).length, lessThanOrEqualTo(74));
  });
}
