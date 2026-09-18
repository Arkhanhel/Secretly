// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/security/auth_signer.dart';

// «Спросить реле, дошло ли» — страховка отправителя больше не пересобирает
// конверт по одному лишь молчанию получателя.
//
// 🔴 ПОЧЕМУ ЭТОТ ТЕСТ ВАЖЕН. Текст подписи обязан посимвольно совпадать с
// `http_pending_check_auth_message` в реле. Расхождение не упало бы НИГДЕ:
// реле молча вернуло бы 401, клиент молча счёл бы «держит» и продолжил
// переотправлять — правка выглядела бы рабочей и не работала. Ровно так
// 11.08.2026 выжил дефект с подтверждениями из фона.
void main() {
  test('🔴 текст подписи совпадает с реле посимвольно', () {
    final msg = utf8.decode(
      AuthSigner.relayHttpPendingCheckMessage(
        deviceId: 'dev-1',
        toDeviceId: 'dev-2',
        msgIds: const ['m1', 'm2'],
        tsMs: 1700000000000,
        nonceB64: 'nonce',
      ),
    );
    expect(
      msg,
      'SECRETLY-RELAY-HTTP-PENDING-CHECK-V1\n'
      'device_id=dev-1\n'
      'to_device_id=dev-2\n'
      'msg_ids=m1,m2\n'
      'ts_ms=1700000000000\n'
      'nonce_b64=nonce\n',
    );
  });

  test('🔴 подпись связывает КАЖДЫЙ msg_id', () {
    // Иначе посредник подменил бы список и заставил отправителя поверить, что
    // доставлено то, что не доставлено, — то есть отменил бы восстановление
    // по-настоящему потерянной смс.
    final a = AuthSigner.relayHttpPendingCheckMessage(
      deviceId: 'd',
      toDeviceId: 't',
      msgIds: const ['m1'],
      tsMs: 1,
      nonceB64: 'n',
    );
    final b = AuthSigner.relayHttpPendingCheckMessage(
      deviceId: 'd',
      toDeviceId: 't',
      msgIds: const ['m2'],
      tsMs: 1,
      nonceB64: 'n',
    );
    expect(a, isNot(equals(b)));
  });

  test('порядок msg_id значим — списки подписываются как есть', () {
    final a = AuthSigner.relayHttpPendingCheckMessage(
      deviceId: 'd',
      toDeviceId: 't',
      msgIds: const ['m1', 'm2'],
      tsMs: 1,
      nonceB64: 'n',
    );
    final b = AuthSigner.relayHttpPendingCheckMessage(
      deviceId: 'd',
      toDeviceId: 't',
      msgIds: const ['m2', 'm1'],
      tsMs: 1,
      nonceB64: 'n',
    );
    expect(a, isNot(equals(b)));
  });
}
