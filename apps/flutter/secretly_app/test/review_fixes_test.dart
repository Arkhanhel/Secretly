// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Проверка после разбора всех правок (26.11.2026): найденное и исправленное.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/message_command_utils.dart';
import 'package:secretly_app/ui/chat/composer_spell_check.dart';
import 'package:secretly_app/ui/chat_message_mentions.dart';

String _slice(String s, String from, [int len = 3000]) {
  final i = s.indexOf(from);
  expect(i, greaterThanOrEqualTo(0), reason: from);
  return s.substring(i, (i + len).clamp(0, s.length));
}

class _Dict implements SpellDictionary {
  _Dict(this.ok);
  final Set<String> ok;
  int asked = 0;
  @override
  Future<List<TextRange>?> check(String text, String language) async {
    final out = <TextRange>[];
    var at = 0;
    for (final w in text.split('\n')) {
      if (!ok.contains(w)) out.add(TextRange(start: at, end: at + w.length));
      at += w.length + 1;
    }
    return out;
  }

  @override
  Future<List<String>> guesses(String word, String language) async {
    asked++;
    return ['$word!'];
  }
}

void main() {
  final chat = File('lib/ui/chat_screen.dart').readAsStringSync();
  final app = File('lib/app/app_controller.dart').readAsStringSync();

  test('🔴 своя неотправленная метка «удалить у всех» ничего не стирает', () {
    final a = _slice(app, 'Future<Set<String>> authorizeDeleteForAll(', 1800);
    expect(a, contains('MessageLocalState.failed'));
    expect(a, contains('MessageLocalState.pending'));
    expect(chat, contains('localState: item.event.localState,'));
  });

  testWidgets('🔴 спойлер, жирный и код вокруг ссылки снова работают', (t) async {
    late BuildContext c;
    await t.pumpWidget(MaterialApp(home: Builder(builder: (x) {
      c = x;
      return const SizedBox();
    })));
    String render(String s) => buildChatMessageTextSpans(
      context: c,
      text: s,
      mentions: const [],
      baseStyle: const TextStyle(),
      isOutgoing: false,
      selfProfileId: 'me',
      currentUserCanReceiveAdminMentions: false,
    ).map((e) => e.toPlainText()).join();
    expect(render('||https://x.com/secret||'), isNot(contains('||')));
    expect(render('**bold https://x.com** tail'), 'bold https://x.com tail');
    expect(render('`curl https://api.x.com/v1`'), 'curl https://api.x.com/v1');
    expect(extractChatMessageLinks('**https://x.com**').single.text, 'https://x.com');
    expect(extractChatMessageLinks('[https://a.com](https://a.com)'), hasLength(2));
    expect(stripChatFormattingMarkers('**https://x.com**'), 'https://x.com');
  });

  test('🔴 испорченная дата события не роняет копирование и поиск', () {
    final bad = buildEventCommand(eventId: 'e', title: 'T', startMs: 100000000000000000);
    expect(parseEventCommand(bad)!.startMs, 0);
    expect(visibleMessageText(bad), '📅 T');
  });

  test('🔴 поиск в длинном чате: предел срезает старые совпадения, не свежие', () {
    final s = _slice(app, 'Future<List<ChatSearchHit>> searchChatMatches({', 7000);
    expect(s, contains('final events = await loadEvents(convoId, limit: scanLimit);'));
    expect(s, contains('hits.sort('));
    expect(s, contains('isCancelled'));
    expect(chat, contains('isCancelled: () => token != _searchRunToken || !mounted,'));
  });

  test('ошибки сверх предела вариантов не застревают без вариантов', () async {
    final d = _Dict({});
    final service = MultiLocaleSpellCheckService(
      deviceLocales: () => const [],
      availableLanguages: () async => const ['ru_RU'],
      singleSystemCall: false,
      dictionary: d,
      debounce: Duration.zero,
    );
    final many = List.generate(45, (i) => 'ошибк${'а' * (i + 1)}').join(' ');
    final first = await service.fetchSpellCheckSuggestions(const Locale('ru'), many);
    expect(first, hasLength(45));
    expect(first!.where((s) => s.suggestions.isEmpty), hasLength(5));
    final second = await service.fetchSpellCheckSuggestions(const Locale('ru'), many);
    expect(second!.where((s) => s.suggestions.isEmpty), isEmpty);
    expect(d.asked, 45);
  });

  test('черновик: не теряется во время уходящей правки и при пересылке', () {
    final p = _slice(chat, 'Future<void> _persistDraft()', 1600);
    expect(p, contains('if (_savedDraftNotLoaded) return;'));
    expect(p, contains('(_draftBeforeEdit ??'));
    expect(chat, contains('if (editingTarget == null && !hasForward) unawaited(_clearDraft());'));
    expect(chat, contains('if (_editingTarget == null) _restoreDraftAfterEdit(merge: true);'));
  });

  test('«прочитали»: счёт по настоящим сменам, пересборка не чаще 1,5 с', () {
    final db = File('lib/storage/app_db.dart').readAsStringSync();
    expect(_slice(db, 'Future<void> roomMessageReceiptUpsert({', 3000),
        contains('if (statusChanged) roomReceiptsSeq++;'));
    expect(chat, contains('Timer(const Duration(milliseconds: 1500)'));
  });

  test('окно темы возвращается, когда из неё ушли', () {
    expect(chat, contains('if (grownFor != null && _currentTopicId != grownFor) {'));
  });
}
