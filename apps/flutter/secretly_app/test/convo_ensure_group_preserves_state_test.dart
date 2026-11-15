// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// 🔴 `convoEnsureGroup` зовётся на каждой отправке в комнату. До 23.10.2026
// он перезаписывал строку беседы целиком и сбрасывал у комнаты «без звука»,
// закреп, архив и таймеры. Здесь сторожится, что состояние человека
// переживает вызов, а название и вид беседы по-прежнему обновляются.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('🔴 повторный вызов не сбрасывает состояние комнаты', () async {
    final db = await AppDb.openForTesting();
    try {
      await db.convoEnsureGroup(groupId: 'group:x', title: 'Old');
      await db.convoSetMuted(convoId: 'group:x', muted: true);
      await db.convoSetPinned(convoId: 'group:x', pinned: true);
      await db.convoSetArchived(convoId: 'group:x', archived: true);
      await db.convoSetAutoDeleteSeconds(
        convoId: 'group:x',
        autoDeleteSeconds: 86400,
      );
      await db.convoSetDisappearSeconds(
        convoId: 'group:x',
        disappearSeconds: 600,
      );
      final before = (await db.convoGet('group:x'))!;

      await db.convoEnsureGroup(groupId: 'group:x', title: 'New');
      final after = (await db.convoGet('group:x'))!;

      for (final column in before.keys) {
        if (column == 'title' || column == 'updated_at_ms') continue;
        expect(after[column], before[column], reason: column);
      }
      expect(after['muted'], 1);
      expect(after['pinned_at_ms'], isNotNull);
      expect(after['archived_at_ms'], isNotNull);
      expect(after['auto_delete_seconds'], 86400);
      expect(after['disappear_seconds'], 600);
      expect(after['title'], 'New');
      expect(after['kind'], 'group');
    } finally {
      await db.close();
    }
  });

  test('первый вызов создаёт беседу комнаты как раньше', () async {
    final db = await AppDb.openForTesting();
    try {
      await db.convoEnsureGroup(groupId: 'group:y', title: 'Y');
      final row = (await db.convoGet('group:y'))!;
      expect(row['kind'], 'group');
      expect(row['title'], 'Y');
      expect(row['muted'], 0);
      expect(row['pinned_at_ms'], isNull);
      expect(row['archived_at_ms'], isNull);
      expect(row['last_event_at_ms'], isNotNull);
      expect(row['created_at_ms'], isNotNull);
    } finally {
      await db.close();
    }
  });
}
