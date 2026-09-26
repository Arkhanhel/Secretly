// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/security/auth_signer.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/relay_protocol.dart';

/// П-1 (ТЗ мультиустройства, 25.09.2026): сверка росписи устройств при
/// отправке, клиентская половина. Всё — за долей `device_check_percent`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('🔴 сводка совпадает с сервером побайтово', () {
    // Те же значения закреплены в Rust: device_set_digest_is_byte_stable.
    expect(deviceSetDigest(['b', 'a']), 'c06a1d67738a6a2cb1fb597dc982308f');
    expect(deviceSetDigest(['a', 'b', 'a', ' ']), 'c06a1d67738a6a2cb1fb597dc982308f');
    expect(deviceSetDigest(const []), '42acae4d4ca6376c3a13ea785a4378e8');
    expect(deviceSetDigest(['dev-2', 'dev-1', 'dev-3']),
        '1200c6f396506d7bab48fa1a114953dd');
  });

  test('кадр без сводки побайтово прежний; sent_ok несёт подсказку', () {
    final plain = jsonDecode(ClientMsg.send(
      toDeviceId: 'd',
      msgId: 'm',
      ciphertextB64: 'QQ==',
      ttlSeconds: 60,
    )) as Map<String, dynamic>;
    expect(plain.containsKey('rcpt_digest'), isFalse);
    final flagged = jsonDecode(ClientMsg.send(
      toDeviceId: 'd',
      msgId: 'm',
      ciphertextB64: 'QQ==',
      ttlSeconds: 60,
      rcptDigest: 'abc',
    )) as Map<String, dynamic>;
    expect(flagged['rcpt_digest'], 'abc');

    final stale = ServerMsg.parse(
      '{"type":"sent_ok","msg_id":"m","device_set_stale":true,"device_ids":["x","y"]}',
    ) as SentOk;
    expect(stale.deviceSetStale, isTrue);
    expect(stale.deviceIds, ['x', 'y']);
    final ok = ServerMsg.parse('{"type":"sent_ok","msg_id":"m"}') as SentOk;
    expect(ok.deviceSetStale, isFalse);
    expect(ok.deviceIds, isNull);
  });

  test('🔴 подписываемая строка связки одного устройства совпадает с Rust', () {
    expect(
      utf8.decode(AuthSigner.keysFetchDeviceBundleMessage(
        requesterDeviceId: 'me',
        deviceId: 'dev-1',
        tsMs: 42,
        nonceB64: 'n',
      )),
      'SECRETLY-KEYS-FETCH-DEVICE-BUNDLE-V1\n'
      'requester_device_id=me\n'
      'device_id=dev-1\n'
      'ts_ms=42\n'
      'nonce_b64=n\n',
    );
  });

  test('на какие устройства уже ушло событие', () async {
    final dir = await Directory.systemTemp.createTemp('device_check');
    final db = await AppDb.openForTesting(path: '${dir.path}/t.db');
    addTearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });
    for (final (id, dev, ev) in [
      ('w1', 'phone', 'local:e1'),
      ('w2', 'desk', 'local:e1'),
      ('w3', 'phone', 'local:e2'),
    ]) {
      await db.outboxUpsert(
        msgId: id,
        toDeviceId: dev,
        ciphertextB64: 'x',
        ttlSeconds: 60,
        state: 'pending',
        attemptCount: 0,
        nextRetryAtMs: 0,
        createdAtMs: 1,
        eventIdRef: ev,
        convoId: 'PEER',
      );
    }
    expect(await db.outboxDeviceIdsForEvent('local:e1'), {'phone', 'desk'});
    expect(await db.outboxDeviceIdsForEvent('local:none'), isEmpty);
  });

  group('порядок в исходнике', () {
    final ctrl = File('lib/app/app_controller.dart').readAsStringSync();
    final sm = File('lib/ratchet/session_manager_v3.dart').readAsStringSync();

    String body(String src, String signature, int span) {
      final start = src.indexOf(signature);
      expect(start, greaterThan(0), reason: signature);
      return src.substring(start, start + span);
    }

    test('🔴 без доли — ни сводки, ни одиночной связки', () {
      expect(
        body(ctrl, 'Future<String?> _deviceCheckDigestForRow(', 300)
            .contains('if (!_deviceCheckActive) return null;'),
        isTrue,
      );
      expect(
        body(ctrl, 'Future<List<Map<String, Object?>>?> _fetchDeviceBundleAuthed(', 300)
            .contains('if (!_deviceCheckActive) return null;'),
        isTrue,
      );
    });

    test('🔴 «устарело» — один раз на пару (событие, профиль)', () {
      final h = body(ctrl, 'void _onDeviceSetStale(', 2500);
      final once = h.indexOf("if (!_deviceSetStaleHandled.add('\$eventRef|\$convo')) return;");
      final refresh = h.indexOf('await refreshContactDevices(convo);');
      expect(once, greaterThan(0));
      expect(refresh, greaterThan(once));
      expect(h.contains('resendBudgetHasRoom('), isTrue, reason: 'бюджет Э-0');
    });

    test('менеджер откатывается на связки профиля, если одиночной нет', () {
      final f = body(sm, 'Future<_PeerBundleV1> _fetchAndVerifyPeerBundle({', 1500);
      expect(
        RegExp(r'final devices = single \?\?\s*await \(fetchBundleAuthed != null')
            .hasMatch(f),
        isTrue,
        reason: 'нет одиночной связки — прежняя выдача профиля',
      );
    });

    test('все места создания клиента реле и менеджера подключены', () {
      int n(String p) => RegExp(RegExp.escape(p)).allMatches(ctrl).length;
      expect(n('relay.onDeviceSetStale = _onDeviceSetStale;'),
          n('relay.onOnlineOnlyDropped = _noteTypingDroppedOffline;'));
      expect(n('fetchDeviceBundleAuthed: _fetchDeviceBundleAuthed,'),
          n('liveSkipJump: _ratchetLiveSkipJump,'));
    });
  });
}
