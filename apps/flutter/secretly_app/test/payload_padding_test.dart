// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// Б2: выравнивание длины полезной нагрузки. Главное свойство — выровненное
// сообщение читает ПРЕЖНИЙ разбор (`E2ePayloadV1.decode` = `jsonDecode`),
// значит выпущенным сборкам ничего менять не нужно.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/entitlements/entitlement_signature.dart';
import 'package:secretly_app/messages/privacy_flags.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/ratchet/payload_padding.dart';
import 'package:secretly_app/storage/app_db.dart';

Uint8List _payload(String text) => Uint8List.fromList(
  E2ePayloadV1(
    senderDeviceId: 'dev:a',
    createdAtMs: 1,
    events: [MsgEventV1(eventId: 'e1', text: text, exp: 60)],
  ).encode(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('корзины: 160/512/1024/2048/4096, дальше — кратно 4096', () {
    expect(paddedPayloadLength(1), 160);
    expect(paddedPayloadLength(160), 160);
    expect(paddedPayloadLength(161), 512);
    expect(paddedPayloadLength(1025), 2048);
    expect(paddedPayloadLength(4096), 4096);
    expect(paddedPayloadLength(4097), 8192);
    expect(paddedPayloadLength(8192), 8192);
  });

  test('🔴 выровненное читается прежним разбором без потерь', () {
    for (final text in ['да', 'нет', 'x' * 300, 'й' * 900, 'a' * 5000]) {
      final plain = _payload(text);
      final padded = padPayloadForWire(plain);
      expect(padded.length, paddedPayloadLength(plain.length));
      final decoded = E2ePayloadV1.decode(padded);
      final msg = decoded.events.single as MsgEventV1;
      expect(msg.text, text);
      expect(msg.exp, 60);
      expect(decoded.senderDeviceId, 'dev:a');
    }
  });

  test('короткие ответы неотличимы по длине', () {
    expect(
      padPayloadForWire(_payload('да')).length,
      padPayloadForWire(_payload('нет, спасибо')).length,
    );
  });

  test('не-JSON и уже выровненное не трогаются', () {
    final raw = Uint8List.fromList(utf8.encode('SKR1 raw bytes'));
    expect(identical(padPayloadForWire(raw), raw), isTrue);
    final once = padPayloadForWire(_payload('hi'));
    expect(identical(padPayloadForWire(once), once), isTrue);
    final empty = Uint8List(0);
    expect(identical(padPayloadForWire(empty), empty), isTrue);
  });

  test('блок privacy: подпись побайтово, непроверенный — доля 0', () {
    expect(
      privacySigningMessage(padSendShare: 10, issuedAtMs: 1760000000123),
      'secretly-privacy-v1|10|1760000000123',
    );
    expect(
      PrivacyFlags.fromConfigResponse(
        {'privacy': {'pad_send_share': 100}},
        verified: false,
      ),
      PrivacyFlags.defaults,
    );
    expect(
      PrivacyFlags.fromConfigResponse(
        {'privacy': {'pad_send_share': 150}},
        verified: true,
      ).padSendShare,
      100,
    );
    expect(const PrivacyFlags(padSendShare: 100).padAllowedFor('p'), isTrue);
    expect(const PrivacyFlags().padAllowedFor('p'), isFalse);
    expect(const PrivacyFlags(padSendShare: 100).padAllowedFor(''), isFalse);
  });

  test('контроллер: без доли провод прежний, в доле — выровнен', () {
    final c = AppController();
    final plain = _payload('hi');
    expect(identical(c.wirePlaintextForTesting(plain), plain), isTrue);
    c.privacyFlagsForTesting = const PrivacyFlags(padSendShare: 100);
    // Профиля нет — не в доле.
    expect(identical(c.wirePlaintextForTesting(plain), plain), isTrue);
  });

  test('контроллер: профиль в доле — провод выровнен и читается', () async {
    final db = await AppDb.openForTesting();
    try {
      final c = AppController()
        ..seedRoomRuntimeForTesting(db: db, profileId: 'me-profile');
      final plain = _payload('hi');
      c.privacyFlagsForTesting = const PrivacyFlags(padSendShare: 100);
      final wire = c.wirePlaintextForTesting(plain);
      expect(wire.length, 160);
      expect((E2ePayloadV1.decode(wire).events.single as MsgEventV1).text, 'hi');
      c.privacyFlagsForTesting = PrivacyFlags.defaults;
      expect(identical(c.wirePlaintextForTesting(plain), plain), isTrue);
    } finally {
      await db.close();
    }
  });
}
