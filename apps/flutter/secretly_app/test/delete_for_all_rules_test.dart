// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// «Удалить у всех» (26.11.2026, разбор Б).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _slice(String s, String from, [int len = 4000]) {
  final i = s.indexOf(from);
  expect(i, greaterThanOrEqualTo(0), reason: from);
  return s.substring(i, (i + len).clamp(0, s.length));
}

void main() {
  final chat = File('lib/ui/chat_screen.dart').readAsStringSync();
  final app = File('lib/app/app_controller.dart').readAsStringSync();

  test('🔴 метка удаления действует только от автора строки', () {
    final a = _slice(app, 'Future<Set<String>> authorizeDeleteForAll(');
    expect(a, contains('rowDid == commander'));
    expect(a, contains('isOwnDeviceId(rowDid) && isOwnDeviceId(commander)'));
    expect(a, contains("!convoId.startsWith('group:')"));
    expect(a, contains('await pidOf(rowDid) == await pidOf(commander)'));
    expect(a, contains('if (!same) continue;'));
    // Лента и список чатов судят одним правилом — сырого сбора меток нет.
    expect(chat, contains('await widget.controller.authorizeDeleteForAll('));
    expect(chat, isNot(contains('deletedPayloadIds.addAll(_parseDeleteForAllCommand')));
    final preview = _slice(app, 'Future<Set<String>> _deletedPayloadIdsFromDecoded(', 600);
    expect(preview, contains('authorizeDeleteForAll(convoId'));
  });

  test('🔴 принятое стирается из базы: не живёт в галерее, поиске, очереди', () {
    final a = _slice(app, 'Future<Set<String>> authorizeDeleteForAll(');
    expect(a, contains('await db.deleteEventsByIds(purge);'));
  });

  test('🔴 фото альбома удаляется у всех, не только первый кадр', () {
    final g = _slice(chat, 'while (j < resolved.length && sameImageGroup(item, resolved[j])) {', 700);
    expect(g, contains('deletedPayloadIds.contains(nextPid)'));
  });

  test('🔴 сначала метка «у всех», потом своё; не ушла — сообщение остаётся', () {
    final d = _slice(chat, 'Future<bool> _deleteEventsConfirmed(', 5000);
    final mark = d.indexOf('_buildDeleteForAllCommand(deleteForAllPayloadIds)');
    final local = d.indexOf('await widget.controller.deleteEventsLocal(');
    expect(mark, greaterThan(0));
    expect(local, greaterThan(mark));
    expect(d.substring(mark, local), contains('return false;'));
  });
}
