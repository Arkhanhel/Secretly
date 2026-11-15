// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Ключи одного созвона: свой ключ, очередь установки по одному, ротация
// с группировкой уходов и ожиданием возврата (ТЗ E2EE созвонов, §4.4).

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/rooms/call_e2ee/call_e2ee_protocol.dart';
import 'package:secretly_app/rooms/call_e2ee/call_key_book.dart';

class _Sink implements CallKeySink {
  final List<String> calls = <String>[];
  int inFlight = 0;
  int maxInFlight = 0;
  Duration latency = Duration.zero;

  @override
  Future<void> setKey(String participantId, int index, Uint8List key) async {
    inFlight += 1;
    maxInFlight = max(maxInFlight, inFlight);
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
    calls.add('set:$participantId:$index:${callKeyFingerprint(key)}');
    inFlight -= 1;
  }

  @override
  Future<void> setOwnEncryptionIndex(int index) async {
    calls.add('own-index:$index');
  }
}

RoomCallKeyGrant _grant(String identity, int epoch, int index, int seed) =>
    RoomCallKeyGrant(
      roomId: 'r',
      callId: 'c',
      identity: identity,
      sentAtMs: 0,
      epoch: epoch,
      keyIndex: index,
      key: Uint8List.fromList(List<int>.filled(32, seed)),
      reason: RoomCallKeyReason.join,
    );

void main() {
  test(
    'свой первый ключ: ячейка 0, ставится себе; эпоха растёт со '
    'временем — перезапуск посреди созвона даёт эпоху больше прежней',
    () async {
      final sink = _Sink();
      var now = DateTime.utc(2026, 10, 6).millisecondsSinceEpoch;
      final book = CallKeyBook(ownIdentity: 'me', sink: sink, nowMs: () => now);
      final own = await book.createInitialOwnKey();
      expect(own.epoch, greaterThan(1));
      // Тот же человек перезапустил приложение через минуту — новая книга.
      now += 60 * 1000;
      final restarted = CallKeyBook(
        ownIdentity: 'me',
        sink: _Sink(),
        nowMs: () => now,
      );
      expect(
        (await restarted.createInitialOwnKey()).epoch,
        greaterThan(own.epoch),
      );
      restarted.dispose();
      expect(own.index, 0);
      expect(own.key.length, 32);
      expect(sink.calls.single, startsWith('set:me:0:'));
      // Повторный вызов не плодит новый ключ.
      expect(identical(await book.createInitialOwnKey(), own), isTrue);
      book.dispose();
    },
  );

  test('🔴 ключи ставятся строго по одному (PBKDF2 в главном потоке)', () {
    fakeAsync((async) {
      final sink = _Sink()..latency = const Duration(milliseconds: 30);
      final book = CallKeyBook(ownIdentity: 'me', sink: sink);
      for (var i = 0; i < 5; i++) {
        book.acceptRemoteKey(_grant('p$i', 1, 0, i));
      }
      async.elapse(const Duration(seconds: 1));
      expect(sink.calls.length, 5);
      expect(sink.maxInFlight, 1);
      book.dispose();
    });
  });

  test('дубль того же ключа не ставится повторно', () {
    fakeAsync((async) {
      final sink = _Sink();
      final book = CallKeyBook(ownIdentity: 'me', sink: sink);
      book.acceptRemoteKey(_grant('p', 1, 0, 1));
      book.acceptRemoteKey(_grant('p', 1, 0, 1));
      async.flushMicrotasks();
      async.elapse(Duration.zero);
      expect(sink.calls.where((c) => c.startsWith('set:p:')).length, 1);
      book.dispose();
    });
  });

  test('устаревший ключ в очереди пропускается — ставится только новый', () {
    fakeAsync((async) {
      final sink = _Sink()..latency = const Duration(milliseconds: 50);
      final book = CallKeyBook(ownIdentity: 'me', sink: sink);
      book.acceptRemoteKey(_grant('busy', 1, 0, 9)); // занимает натив
      book.acceptRemoteKey(_grant('p', 1, 0, 1));
      book.acceptRemoteKey(_grant('p', 2, 1, 2)); // новее, пока первый ждёт
      async.elapse(const Duration(seconds: 1));
      final forP = sink.calls.where((c) => c.startsWith('set:p:')).toList();
      expect(forP.length, 1);
      expect(forP.single, startsWith('set:p:1:'));
      book.dispose();
    });
  });

  test('ротация: новая ячейка ставится сразу, шифрование переходит '
      'через задержку', () {
    fakeAsync((async) {
      final sink = _Sink();
      final book = CallKeyBook(
        ownIdentity: 'me',
        sink: sink,
        keySwitchDelay: const Duration(seconds: 2),
      );
      unawaited(book.createInitialOwnKey());
      async.flushMicrotasks();
      late OwnCallKey rotated;
      book.rotateOwnKey().then((k) => rotated = k);
      async.flushMicrotasks();
      async.elapse(Duration.zero);
      expect(rotated.epoch, book.ownKey!.epoch);
      expect(rotated.epoch, greaterThan(1));
      expect(rotated.index, 1);
      expect(sink.calls.any((c) => c.startsWith('set:me:1:')), isTrue);
      expect(sink.calls.contains('own-index:1'), isFalse);
      expect(book.activeOwnIndex, 0);
      async.elapse(const Duration(milliseconds: 1999));
      expect(sink.calls.contains('own-index:1'), isFalse);
      async.elapse(const Duration(milliseconds: 1));
      expect(sink.calls.contains('own-index:1'), isTrue);
      expect(book.activeOwnIndex, 1);
      book.dispose();
    });
  });

  test('кольцо из 16: после ячейки 15 — снова 0', () async {
    final sink = _Sink();
    final book = CallKeyBook(ownIdentity: 'me', sink: sink);
    final first = await book.createInitialOwnKey();
    OwnCallKey? last;
    for (var i = 0; i < 16; i++) {
      last = await book.rotateOwnKey();
    }
    expect(last!.index, 0);
    expect(last.epoch, first.epoch + 16);
    book.dispose();
  });

  test('явные уходы за 1,5 с собираются в одну ротацию', () {
    fakeAsync((async) {
      final sink = _Sink();
      final book = CallKeyBook(ownIdentity: 'me', sink: sink);
      final rotations = <OwnCallKey>[];
      book.onOwnKeyRotated = rotations.add;
      unawaited(book.createInitialOwnKey());
      async.flushMicrotasks();
      book.onParticipantGone('a', explicit: true);
      async.elapse(const Duration(milliseconds: 700));
      book.onParticipantGone('b', explicit: true);
      async.elapse(const Duration(milliseconds: 900));
      expect(rotations.length, 1);
      async.elapse(const Duration(seconds: 5));
      expect(rotations.length, 1);
      book.dispose();
    });
  });

  test('пропал только транспорт и вернулся за 15 с — ротации нет', () {
    fakeAsync((async) {
      final sink = _Sink();
      final book = CallKeyBook(ownIdentity: 'me', sink: sink);
      final rotations = <OwnCallKey>[];
      book.onOwnKeyRotated = rotations.add;
      unawaited(book.createInitialOwnKey());
      async.flushMicrotasks();
      book.onParticipantGone('a', explicit: false);
      async.elapse(const Duration(seconds: 10));
      book.onParticipantBack('a');
      async.elapse(const Duration(seconds: 30));
      expect(rotations, isEmpty);
      book.dispose();
    });
  });

  test('пропал транспорт и не вернулся — ротация после 15 с', () {
    fakeAsync((async) {
      final sink = _Sink();
      final book = CallKeyBook(ownIdentity: 'me', sink: sink);
      final rotations = <OwnCallKey>[];
      book.onOwnKeyRotated = rotations.add;
      unawaited(book.createInitialOwnKey());
      async.flushMicrotasks();
      book.onParticipantGone('a', explicit: false);
      async.elapse(const Duration(seconds: 15));
      expect(rotations, isEmpty, reason: 'ещё идёт сбор уходов');
      async.elapse(const Duration(seconds: 2));
      expect(rotations.length, 1);
      book.dispose();
    });
  });

  test('ушедший теряет ключ в книге: его ключ в очереди не ставится', () {
    fakeAsync((async) {
      final sink = _Sink()..latency = const Duration(milliseconds: 50);
      final book = CallKeyBook(ownIdentity: 'me', sink: sink);
      book.acceptRemoteKey(_grant('busy', 1, 0, 9));
      book.acceptRemoteKey(_grant('gone', 1, 0, 1));
      book.onParticipantGone('gone', explicit: true);
      async.elapse(const Duration(seconds: 1));
      expect(sink.calls.any((c) => c.startsWith('set:gone:')), isFalse);
      book.dispose();
    });
  });

  test('после dispose ключи затёрты и ничего не ставится', () async {
    final sink = _Sink();
    final book = CallKeyBook(ownIdentity: 'me', sink: sink);
    final own = await book.createInitialOwnKey();
    book.dispose();
    expect(own.key.every((b) => b == 0), isTrue);
    sink.calls.clear();
    book.acceptRemoteKey(_grant('p', 1, 0, 1));
    await Future<void>.delayed(Duration.zero);
    expect(sink.calls, isEmpty);
  });

  test('счётчик ключей за минуту', () {
    fakeAsync((async) {
      var now = 0;
      final book = CallKeyBook(
        ownIdentity: 'me',
        sink: _Sink(),
        nowMs: () => now,
      );
      for (var i = 0; i < 3; i++) {
        book.acceptRemoteKey(_grant('p', i + 1, i, i));
      }
      expect(book.grantsFromLastMinute('p'), 3);
      now += 61000;
      expect(book.grantsFromLastMinute('p'), 0);
      book.dispose();
    });
  });
}
