// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ANR на Xiaomi (24.11.2026, сборка 752): автокопия при возвращении в
// приложение шифровалась в главном изоляте — почти минута без ответа на
// касания. Шифрование и расшифровка копии идут в отдельном изоляте.

import 'dart:io';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

void main() {
  test('шифрование и расшифровка копии — через Isolate.run', () {
    final src = File('lib/security/safe_backup.dart').readAsStringSync();
    expect(src, contains("debugName: 'safe_backup_encrypt'"));
    expect(src, contains("debugName: 'safe_backup_decrypt'"));
    expect(src, contains('() => _encryptBody(plain, password, iterations)'));
    expect(src, contains('() => _decryptBody(payload, password)'));
  });

  test('крупный файл кодируется в изоляте — байт в байт', () async {
    final dir = Directory.systemTemp.createTempSync('b64');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/big.bin')
      ..writeAsBytesSync(List<int>.generate(600 * 1024, (i) => i % 251));
    expect(await readFileBase64OffUi(f.path),
        base64Encode(f.readAsBytesSync()));
  });
}
