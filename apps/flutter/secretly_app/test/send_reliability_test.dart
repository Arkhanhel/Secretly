// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Надёжность написания и отправки (26.11.2026, разбор «что ещё не так»):
// текст не теряется, правки доходят, отложенное слушается.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _slice(String s, String from, [int len = 9000]) {
  final i = s.indexOf(from);
  expect(i, greaterThanOrEqualTo(0), reason: from);
  return s.substring(i, (i + len).clamp(0, s.length));
}

void main() {
  final chat = File('lib/ui/chat_screen.dart').readAsStringSync();
  final app = File('lib/app/app_controller.dart').readAsStringSync();
  final db = File('lib/storage/app_db.dart').readAsStringSync();

  test('🔴 вторая отправка не пропадает: очередь, а не «занято»', () {
    expect(chat, isNot(contains('_sendInFlight')));
    final send = _slice(chat, 'Future<void> _sendInner', 30000);
    expect(send, contains('final previous = _sendChain;'));
    expect(send, contains('turn.complete();'));
    // Всё нужное забрано из поля до первого ожидания сети.
    final capture = send.substring(0, send.indexOf('await previous;'));
    for (final s in ['_text.clear()', 'final replyTarget = _replyTo;',
        'final forwardDraft = _forwardDraft;', 'final topicId = _currentTopicId;']) {
      expect(capture, contains(s));
    }
    expect(send, isNot(contains('topicId: _currentTopicId')));
  });

  test('🔴 ошибка без пузыря возвращает текст, ответ и остаток пересылки', () {
    final send = _slice(chat, 'Future<void> _sendInner', 30000);
    expect(send, contains('void restoreComposer()'));
    expect(send, contains('outgoingInsertSeqFor(chatIds) ==\n          chatInsertSeqBefore'));
    final catchAt = send.indexOf('} catch (e) {\n      if (!mounted) return;');
    expect(send.substring(catchAt, catchAt + 120), contains('restoreComposer();'));
    expect(db, contains('if (localState != \'received\') {\n      outgoingInsertSeq++;'));
  });

  test('🔴 «отправить всё равно» повторяет красный пузырь, а не шлёт второй', () {
    final send = _slice(chat, "if (choice == 'send') {", 1500);
    expect(send, contains('failedOutgoingInsertedSince'));
    expect(send, contains('retryOutgoingEventSend('));
  });

  test('🔴 черновик: сохраняется по ходу набора и в фоне; правка его не стирает', () {
    expect(chat, contains('_draftLifecycle = AppLifecycleListener('));
    expect(chat, contains('_draftSaveTimer = Timer('));
    final persist = _slice(chat, 'Future<void> _persistDraft()', 1200);
    expect(persist, contains('_draftBeforeEdit'));
    expect(persist, contains('if (_editingTarget == null && _forwardDraft != null) return;'));
    expect(_slice(chat, 'void _cancelEdit()', 400), contains('_restoreDraftAfterEdit()'));
    expect(_slice(chat, 'void _startReply({', 900), contains('_restoreDraftAfterEdit()'));
  });

  test('«печатает» — только живой набор в поле с фокусом', () {
    final f = _slice(chat, 'void _onComposerTextChanged()', 1200);
    expect(f, contains('_messageInputFocusNode.hasFocus'));
    expect(f, contains('typedText != _typingSeenText'));
  });

  test('🔴 правка живёт неделю, как сообщение, а не служебный час', () {
    final edit = _slice(app, 'var peerEditNeeded = true;', 7000);
    expect(
      RegExp('ttlSeconds: _outboxUserMessageTtlSeconds').allMatches(edit).length,
      greaterThanOrEqualTo(2),
    );
  });

  test('🔴 правка в комнате со второго своего устройства', () {
    final apply = _slice(app, 'Future<bool> _applyMessageEditLocal({', 3000);
    expect(apply, contains('deviceProfileCached(senderDid)'));
    final mirror = _slice(app, 'Future<void> _mirrorMessageEditToOwnDevices({', 900);
    expect(mirror, isNot(contains("startsWith('group:')")));
  });

  test('🔴 отложенное на реле: правка, удаление и «сейчас» его отзывают', () {
    expect(app, contains('_reissueHeldScheduledDirect(\n    String localEventId, {'));
    expect(_slice(app, 'Future<int> deleteEventsLocal({', 1900),
        contains('_reissueHeldScheduledDirect(id, drop: true)'));
    expect(app, contains('deliverAtMs: editDeliverAtMs,'));
    expect(_slice(app, 'Future<void> sendScheduledMessageNow({', 900),
        contains('_reissueHeldScheduledDirect(id, deliverAtMs: 0)'));
    expect(app, contains('if (peerEditNeeded &&'));
    // Выданную копию отозвать нельзя: отказ реле не считается отзывом.
    final r = _slice(app, '_reissueHeldScheduledDirect(\n    String localEventId, {', 4000);
    // «Нет ответа» — не «выдано»: старая копия может прийти в срок.
    expect(r, contains('if (cancelled == null) {'));
    expect(r, contains('state == OutboxSendState.sending'));
  });
}
