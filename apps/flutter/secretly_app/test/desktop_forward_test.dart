// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/app/message_command_utils.dart';
import 'package:secretly_app/ui/desktop/chat/message_context_menu.dart';
import 'package:secretly_app/ui/desktop/primitives/context_menu.dart';

/// Pins the two invariants the desktop «Переслать» feature rests on.
///
/// 1. The wire format is the SHARED forward command, so a message forwarded
///    from desktop renders with proper attribution on mobile (and vice versa).
///    If `buildForwardCommand` / `parseForwardCommand` ever drift apart, the
///    forward silently degrades into a bare copy with the wrong author —
///    exactly the kind of silent data-fidelity loss that is hard to spot in QA.
///
/// 2. The context menu never renders an action it cannot perform
///    («no dead affordances», DESKTOP_COMPLETION_TZ principle P-5).
void main() {
  group('desktop forward wire format', () {
    test('round-trips text and attribution', () {
      final cmd = buildForwardCommand(
        authorName: 'Алиса',
        text: 'привет из десктопа',
        authorProfileId: 'pid-alice',
        sourceConvoId: 'convo-1',
      );

      final parsed = parseForwardCommand(cmd);
      expect(parsed, isNotNull);
      expect(parsed!.text, 'привет из десктопа');
      expect(parsed.authorName, 'Алиса');
    });

    test('a plain message is not mistaken for a forward', () {
      expect(parseForwardCommand('обычное сообщение'), isNull);
      expect(parseForwardCommand(''), isNull);
    });

    test('survives text that itself looks like a command', () {
      final cmd = buildForwardCommand(
        authorName: 'Боб',
        text: '__secretly_delete__:not-really',
      );
      final parsed = parseForwardCommand(cmd);
      expect(parsed, isNotNull);
      // The inner text must come back verbatim — the wrapper must not let the
      // payload escape and be re-interpreted as a control command.
      expect(parsed!.text, '__secretly_delete__:not-really');
    });

    test('preserves an empty author rather than inventing one', () {
      final cmd = buildForwardCommand(authorName: '', text: 'x');
      final parsed = parseForwardCommand(cmd);
      expect(parsed, isNotNull);
      expect(parsed!.authorName, '');
    });
  });

  group('message context menu — no dead affordances', () {
    List<String> labelsOf(List<List<CtxMenuItem>> sections) =>
        sections.expand((s) => s).map((i) => i.label).toList();

    test('omits forward when no handler is supplied', () {
      final sections = MessageContextMenu.sections(
        isSelf: true,
        canEdit: true,
        canDelete: true,
        canPin: true,
        onCopy: () {},
      );
      expect(labelsOf(sections), isNot(contains('Переслать')));
    });

    test('shows forward once a handler is supplied', () {
      final sections = MessageContextMenu.sections(
        isSelf: true,
        canEdit: true,
        canDelete: true,
        canPin: true,
        onCopy: () {},
        onForward: () {},
      );
      expect(labelsOf(sections), contains('Переслать'));
    });

    test('never emits an empty section (no stray dividers)', () {
      final sections = MessageContextMenu.sections(
        isSelf: false,
        canEdit: false,
        canDelete: false,
        canPin: false,
        onCopy: () {},
      );
      expect(sections, isNotEmpty);
      for (final section in sections) {
        expect(section, isNotEmpty);
      }
    });

    test('unimplemented pin and select stay hidden', () {
      final sections = MessageContextMenu.sections(
        isSelf: true,
        canEdit: true,
        canDelete: true,
        canPin: true,
        onReply: () {},
      );
      final labels = labelsOf(sections);
      expect(labels, isNot(contains('Закрепить')));
      expect(labels, isNot(contains('Выделить')));
    });
  });
}
