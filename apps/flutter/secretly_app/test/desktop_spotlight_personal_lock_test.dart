// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart' show Conversation;
import 'package:secretly_app/ui/desktop/app/desktop_spotlight.dart';

// 🔴 ⌘K ПОКАЗЫВАЛ ЗАКРЫТЫЕ «ЛИЧНЫЕ» ЧАТЫ (17.09.2026).
//
// Палитра обходила все переписки: названия и куски текста личных чатов,
// спрятанных за паролем, находились поиском. Пока область заперта, их нет.

Conversation _c(String id, {String? peer}) => Conversation(
  convoId: id,
  peerProfileId: peer,
  title: 'Чат $id',
  avatarPath: null,
  lastEventAtMs: 1,
  pinnedAtMs: null,
  muted: false,
  archivedAtMs: null,
  autoDeleteSeconds: null,
  emoji: null,
);

void main() {
  final all = [_c('P1', peer: 'P1'), _c('P2', peer: 'P2'), _c('group:R1')];
  bool isPersonal(String id) => id == 'P2';

  test('🔴 заперто — личного чата в поиске нет', () {
    final visible = spotlightSearchableConversations(
      all,
      personalLocked: true,
      isPersonal: isPersonal,
    );
    expect(visible.map((c) => c.convoId), ['P1', 'group:R1']);
  });

  test('открыто или пароля нет — ищется всё', () {
    final visible = spotlightSearchableConversations(
      all,
      personalLocked: false,
      isPersonal: isPersonal,
    );
    expect(visible.map((c) => c.convoId), ['P1', 'P2', 'group:R1']);
  });

  test('все три обхода идут по отфильтрованному списку', () {
    final src = File(
      'lib/ui/desktop/app/desktop_spotlight.dart',
    ).readAsStringSync();
    expect(
      src.contains('SecurityLockScope.personal'),
      isTrue,
      reason: 'фильтр смотрит на замок личных',
    );
    expect(src.contains('_conversations = visible;'), isTrue);
    // Названия, текст и файлы — только по _conversations.
    expect(
      RegExp(r'controller\.listConversations\(\)').allMatches(src).length,
      1,
      reason: 'второго источника переписок, минующего фильтр, нет',
    );
  });
}
