// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:secretly_app/app/app_controller.dart'
    show kSecretlySupportedAppLinkHosts, tryParseProfileShareUri;
import 'package:secretly_app/security/qr_payload.dart';
import 'package:secretly_app/ui/desktop/app/desktop_contacts_section.dart'
    show resolveDesktopContactInput, resolveDesktopContactName;

/// Точная копия `QrPayload.tryParse` до 23.11.2026 — так QR читают сборки,
/// которые уже стоят у людей. Новый QR обязан разбираться и ею.
Map<String, String?> legacyTryParse(String raw) {
  final s = raw.trim();
  if (s.isEmpty) {
    return const {'id': null, 'dev': null, 'ik': null, 'nick': null, 'keys': null};
  }
  final parts = s.split(RegExp(r'[\n&]+'));
  final map = <String, String>{};
  for (final p in parts) {
    final idx = p.indexOf('=');
    if (idx <= 0) continue;
    final k = p.substring(0, idx).trim().toLowerCase();
    final v = p.substring(idx + 1).trim();
    if (k.isEmpty || v.isEmpty) continue;
    map[k] = v;
  }
  String? pick(List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  return {
    'id': pick(['secretly_id', 'secretlyid', 'profile_id', 'profileid']),
    'dev': pick(['device_id', 'deviceid']),
    'ik': pick(['identity_key_pub_b64', 'identitykeypubb64', 'ik_b64']),
    'nick': pick(['nickname', 'name', 'display_name', 'displayname']),
    'keys': pick(['keys_base_url', 'keysbaseurl', 'server', 'srv']),
  };
}

// Как выдаёт сервер ключей: 13 знаков Base32 по 4 + 7 знаков CRC.
const _id = 'K7QD-M2XA-PL4RZ-B3TQW5Y';
const _dev = 'c0ffee12-3456-4789-abcd-ef0123456789';
// base64 открытого ключа X25519/Ed25519 (32 байта) с `+`, `/` и `=`.
const _ik = 'q+7/Zx9aB3cD4eF5gH6iJ7kL8mN9oP0qR1sT2uV3w+/=';
const _keys = 'https://keys.secretlyapp.com';

String _link({String? nick, String? ik = _ik}) => QrPayload.buildContactLink(
  secretlyId: _id,
  keysBaseUrl: _keys,
  deviceId: _dev,
  identityKeyPubB64: ik,
  nickname: nick,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('QrPayload parses newline key=value format', () {
    final p = QrPayload.tryParse(
      'secretly_id=ABC-123\n'
      'device_id=dev1\n'
      'identity_key_pub_b64=IKB64\n'
      'nickname=Alice',
    );
    expect(p.secretlyId, 'ABC-123');
    expect(p.deviceId, 'dev1');
    expect(p.identityKeyPubB64, 'IKB64');
    expect(p.nickname, 'Alice');
  });

  test('QrPayload parses ampersand format + aliases', () {
    final p = QrPayload.tryParse('profile_id=PID&deviceid=DID&ik_b64=IK&name=Bob');
    expect(p.secretlyId, 'PID');
    expect(p.deviceId, 'DID');
    expect(p.identityKeyPubB64, 'IK');
    expect(p.nickname, 'Bob');
  });

  test('old plain-text QR (as printed before 23.11) still parses', () {
    final p = QrPayload.tryParse(
      'secretly_id=$_id\nkeys_base_url=$_keys\ndevice_id=$_dev\n'
      'identity_key_pub_b64=$_ik\nnickname=Алиса',
    );
    expect(p.secretlyId, _id);
    expect(p.keysBaseUrl, _keys);
    expect(p.deviceId, _dev);
    expect(p.identityKeyPubB64, _ik);
    expect(p.nickname, 'Алиса');
    expect(p.hasDeviceKey, isTrue);
  });

  test('new link has the agreed exact shape', () {
    expect(
      _link(nick: 'Alice B'),
      'https://links.secretlyapp.com/profile/$_id'
      '#v=1&secretly_id=$_id&device_id=$_dev'
      '&identity_key_pub_b64=$_ik&keys_base_url=$_keys&nn=QWxpY2UgQg',
    );
    // Без ника (настройка «показывать ник в QR» выключена) — без `nn`.
    expect(_link(), isNot(contains('nn=')));
    expect(_link(), isNot(contains('nickname=')));
    // Ключ и адрес сервера — как есть, без %-кодирования.
    expect(_link(), contains('identity_key_pub_b64=$_ik&'));
    expect(_link(), contains('keys_base_url=$_keys'));
  });

  test('new link round-trips: base64 +/= and Cyrillic nickname', () {
    final raw = _link(nick: 'Юрий & Ко #1');
    final p = QrPayload.tryParse(raw);
    expect(p.secretlyId, _id);
    expect(p.deviceId, _dev);
    expect(p.identityKeyPubB64, _ik);
    expect(p.keysBaseUrl, _keys);
    expect(p.nickname, 'Юрий & Ко #1');
    expect(p.hasDeviceKey, isTrue);
  });

  test('new link survives Uri.parse().toString() (deep link path)', () {
    final raw = _link(nick: 'Юрий');
    final viaUri = Uri.parse(raw).toString();
    final p = QrPayload.tryParse(viaUri);
    expect(p.secretlyId, _id);
    expect(p.identityKeyPubB64, _ik);
    expect(p.nickname, 'Юрий');
    // И путь по-прежнему узнаётся общим разборщиком ссылок профиля.
    expect(tryParseProfileShareUri(Uri.parse(raw)), _id);
  });

  test('bare profile link without fragment gives id only', () {
    for (final host in kSecretlySupportedAppLinkHosts) {
      final p = QrPayload.tryParse('https://$host/profile/$_id');
      expect(p.secretlyId, _id, reason: host);
      expect(p.deviceId, isNull);
      expect(p.identityKeyPubB64, isNull);
      expect(p.hasDeviceKey, isFalse);
    }
    expect(QrPayload.tryParse('secretly://profile/$_id').secretlyId, _id);
  });

  test('extra unknown fragment keys are ignored', () {
    final raw = '${_link(nick: 'Bob')}&future_key=zzz&x=1';
    final p = QrPayload.tryParse(raw);
    expect(p.secretlyId, _id);
    expect(p.deviceId, _dev);
    expect(p.identityKeyPubB64, _ik);
    expect(p.nickname, 'Bob');
  });

  test('fragment naming another profile than the path is not trusted', () {
    final raw =
        'https://links.secretlyapp.com/profile/$_id'
        '#v=1&secretly_id=someone-else&device_id=$_dev&identity_key_pub_b64=$_ik';
    final p = QrPayload.tryParse(raw);
    expect(p.secretlyId, _id);
    expect(p.hasDeviceKey, isFalse);
  });

  test('foreign host link falls back to the old key=value parsing', () {
    final p = QrPayload.tryParse(
      'https://example.com/x#a=1&secretly_id=PID&device_id=D',
    );
    expect(p.secretlyId, 'PID');
    expect(p.deviceId, 'D');
  });

  test('OLD parser still extracts id/device/ik/server from the new link', () {
    for (final nick in <String?>[null, 'Alice', 'Юрий']) {
      final old = legacyTryParse(_link(nick: nick));
      expect(old['id'], _id);
      expect(old['dev'], _dev);
      expect(old['ik'], _ik);
      expect(old['keys'], _keys);
      // Ник старые сборки просто не видят — ни мусора, ни %-кодов.
      expect(old['nick'], isNull);
    }
    // Голая ссылка без хвоста: старая сборка, как и раньше со всяким
    // «чужим» текстом, ID не найдёт (покажет «нет Secretly ID»).
    expect(legacyTryParse('https://links.secretlyapp.com/profile/$_id')['id'],
        isNull);
  });

  test('link without identity key omits it (like the old text)', () {
    final raw = _link(ik: null);
    expect(raw, isNot(contains('identity_key_pub_b64')));
    final p = QrPayload.tryParse(raw);
    expect(p.deviceId, _dev);
    expect(p.hasDeviceKey, isFalse);
  });

  test('QR stays scannable at the smallest on-screen size', () {
    // Длинный ник в кириллице — худший случай по длине.
    final raw = _link(nick: 'Александра Константинопольская');
    final result = QrValidator.validate(
      data: raw,
      errorCorrectionLevel: QrErrorCorrectLevel.L,
    );
    expect(result.status, QrValidationStatus.valid);
    final version = result.qrCode!.typeNumber;
    final modules = 17 + 4 * version;
    // 180 логических px — нижняя граница qrSize на экране «Мой ID».
    // Не меньше ~2,5 логических px (≈7–8 физических) на модуль.
    expect(180 / modules, greaterThan(2.5), reason: 'version $version');
  });

  test('desktop contact input resolves id and name from the new link', () {
    final raw = _link(nick: 'Юрий');
    expect(resolveDesktopContactInput(raw), _id);
    expect(resolveDesktopContactName(raw), 'Юрий');
    expect(
      resolveDesktopContactInput('https://links.secretlyapp.com/profile/$_id'),
      _id,
    );
  });
}
