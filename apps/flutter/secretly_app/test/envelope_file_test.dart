// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/crypto/dart_crypto_provider.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/envelope_file.dart';
import 'package:secretly_app/ui/network_settings_screen.dart'
    show isOfflineEnvelopeFileName;
import 'package:shared_preferences/shared_preferences.dart';

// Э4а: конверты файлом. Формат с подписью; импорт кладёт во входящие только
// своё и только новое.

List<OfflineEnvelope> _envs() => const <OfflineEnvelope>[
  OfflineEnvelope(msgId: 'm-1', toDeviceId: 'bob-phone', ciphertextB64: 'U0tTMgAB'),
  OfflineEnvelope(msgId: 'm-2', toDeviceId: 'bob-mac', ciphertextB64: 'U0tTMgAC'),
  OfflineEnvelope(msgId: 'm-3', toDeviceId: 'bob-phone', ciphertextB64: 'U0tTMgAD'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('🔴 круг: собрать → разобрать; подпись проверяется', () async {
    final key = await Ed25519().newKeyPair();
    final bytes = await EnvelopeFile.build(
      fromDeviceId: 'alice-phone',
      createdAtMs: 1000,
      envelopes: _envs(),
      deviceIdentity: key,
    );
    final parsed = await EnvelopeFile.parse(bytes);
    expect(parsed.fromDeviceId, 'alice-phone');
    expect(parsed.envelopes.map((e) => e.msgId), <String>['m-1', 'm-2', 'm-3']);
    expect(parsed.senderKeyKnown, isFalse);

    final pub = base64Encode((await key.extractPublicKey()).bytes);
    final again = await EnvelopeFile.parse(bytes, knownIdentityPubB64: pub);
    expect(again.senderKeyKnown, isTrue);
  });

  test('🔴 подмена конверта и чужой ключ отвергаются', () async {
    final key = await Ed25519().newKeyPair();
    final bytes = await EnvelopeFile.build(
      fromDeviceId: 'alice-phone',
      createdAtMs: 1000,
      envelopes: _envs(),
      deviceIdentity: key,
    );
    final tampered = utf8.encode(utf8.decode(bytes).replaceFirst('U0tTMgAB', 'U0tTMgZZ'));
    expect(
      () => EnvelopeFile.parse(tampered),
      throwsA(isA<EnvelopeFileException>().having((e) => e.code, 'code', 'bad_signature')),
    );
    final other = await Ed25519().newKeyPair();
    final otherPub = base64Encode((await other.extractPublicKey()).bytes);
    expect(
      () => EnvelopeFile.parse(bytes, knownIdentityPubB64: otherPub),
      throwsA(isA<EnvelopeFileException>().having((e) => e.code, 'code', 'sender_key_mismatch')),
    );
    expect(
      () => EnvelopeFile.parse(utf8.encode('not json')),
      throwsA(isA<EnvelopeFileException>()),
    );
  });

  test('файл сообщений узнаётся по расширению или по типу, не иначе', () {
    expect(isOfflineEnvelopeFileName('messages-20261011.secretly'), isTrue);
    expect(isOfflineEnvelopeFileName('/cache/share_1/MESSAGES.SECRETLY'), isTrue);
    expect(isOfflineEnvelopeFileName('share_1', mime: EnvelopeFile.mimeType), isTrue);
    expect(isOfflineEnvelopeFileName('photo.jpg', mime: 'image/jpeg'), isFalse);
    expect(isOfflineEnvelopeFileName('secretly.txt'), isFalse);
    expect(isOfflineEnvelopeFileName(null), isFalse);
  });

  test('имя файла не выдаёт собеседника и время', () {
    expect(
      EnvelopeFile.suggestedFileName(DateTime.utc(2026, 10, 11, 23, 59)),
      'messages-20261011.secretly',
    );
  });

  test('🔴 импорт: только конверты этого устройства и только новые', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final dir = await Directory.systemTemp.createTemp('secretly_envfile_');
    addTearDown(() => dir.delete(recursive: true));
    final db = await AppDb.openForTesting(path: '${dir.path}/bob.db');
    addTearDown(db.close);
    final bob = AppController()
      ..seedRoomRuntimeForTesting(
        db: db,
        profileId: 'bob',
        deviceId: 'bob-phone',
        crypto: DartCryptoProvider(Uint8List(32)),
      );
    // m-3 уже приходил через реле.
    await db.inboxMarkSeen('m-3');
    final key = await Ed25519().newKeyPair();
    final bytes = await EnvelopeFile.build(
      fromDeviceId: 'alice-phone',
      createdAtMs: 1000,
      envelopes: _envs(),
      deviceIdentity: key,
    );
    final imported = await bob.importOfflineEnvelopes(bytes);
    expect(imported, 1, reason: 'm-1 — да; m-2 — чужое устройство; m-3 — уже был');
  });
}
