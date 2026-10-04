// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ОБНОВЛЕНИЕ WINDOWS: ИТОГ ПОПЫТКИ И УБОРКА УСТАНОВЩИКОВ (30.09.2026).
//
// - Неудача была видна только кнопкой до перезапуска, а установщик, который
//   не встал, не оставлял следа вовсе. Теперь итог — в `lastAttempt`, в том
//   числе итог самого установщика, узнанный при следующем запуске.
// - Скачанные установщики копились во временной папке по одному на каждое
//   обновление.

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_update_service.dart';

import 'support/synthetic_pe.dart';

const _url =
    'https://updates.secretlyapp.com/Secretly-Setup-1.8.63-642-x64.exe';

void main() {
  late Directory tmp;
  late Directory dl;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('secretly-update-attempt');
    dl = Directory('${tmp.path}/dl')..createSync();
    DesktopUpdateService.debugDownloadDir = dl;
  });

  tearDown(() {
    DesktopUpdateService.instance.debugReset();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  File pending() => File('${dl.path}/pending-update.json');

  File leftover(String name) =>
      File('${dl.path}/$name')..writeAsBytesSync([1, 2, 3]);

  /// Подписанный «установщик» в папке скачивания и служба, готовая его
  /// поставить; [launchFails] — установщик не запускается.
  Future<({File setup, List<String> launched})> prepare({
    bool badSignature = false,
    bool launchFails = false,
  }) async {
    final bytes = buildSyntheticPe(
      major: 1,
      minor: 8,
      patch: 63,
      build: 642,
      padding: 2000,
    );
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final signature = await algorithm.sign(bytes, keyPair: keyPair);
    final publicKey = await keyPair.extractPublicKey();
    final setup = File('${dl.path}/Secretly-Setup-1.8.63-642-x64.exe');
    final launched = <String>[];
    final service = DesktopUpdateService.instance
      ..debugWindowsPath = true
      ..debugPublicKeyB64 = base64Encode(
        badSignature ? List<int>.filled(32, 7) : publicKey.bytes,
      )
      ..debugDownloader = (url, length, onProgress) async {
        // Файл появляется при скачивании — после уборки прежних.
        setup.writeAsBytesSync(bytes);
        return setup;
      }
      ..debugLauncher = (path, args) async {
        if (launchFails) throw const FileSystemException('blocked');
        launched.add(path);
      }
      ..debugQuit = () async {};
    service.available.value = DesktopUpdateOffer(
      version: '1.8.63',
      build: 642,
      downloadUrl: _url,
      edSignature: base64Encode(signature.bytes),
      length: bytes.length,
    );
    return (setup: setup, launched: launched);
  }

  test('установщик запущен: прежние скачанные убраны, этот — на месте, '
      'итог ждёт перезапуска', () async {
    final old = leftover('Secretly-Setup-1.8.62-635-x64.exe');
    final r = await prepare();

    await DesktopUpdateService.instance.install();

    expect(r.launched, [r.setup.path]);
    expect(old.existsSync(), isFalse, reason: 'прежний установщик убран');
    expect(r.setup.existsSync(), isTrue, reason: 'запущенный не трогаем');
    expect(pending().existsSync(), isTrue);
    expect(jsonDecode(pending().readAsStringSync()), {
      'version': '1.8.63',
      'build': 642,
    });
    expect(DesktopUpdateService.instance.lastAttempt.value, isNull);
  });

  test('🔴 после перезапуска на новой сборке — «обновление встало», '
      'установщик убран', () async {
    pending().writeAsStringSync('{"version":"1.8.63","build":642}');
    final used = leftover('Secretly-Setup-1.8.63-642-x64.exe');
    final service = DesktopUpdateService.instance..debugCurrentBuild = 642;

    await service.settlePreviousAttempt();

    final attempt = service.lastAttempt.value!;
    expect(attempt.succeeded, isTrue);
    expect(attempt.version, '1.8.63');
    expect(attempt.build, 642);
    expect(pending().existsSync(), isFalse);
    expect(used.existsSync(), isFalse);
  });

  test('🔴 после перезапуска на прежней сборке — «не установилось»', () async {
    pending().writeAsStringSync('{"version":"1.8.63","build":642}');
    final service = DesktopUpdateService.instance..debugCurrentBuild = 635;

    await service.settlePreviousAttempt();

    expect(
      service.lastAttempt.value!.failure,
      DesktopUpdateFailure.notInstalled,
    );
    expect(pending().existsSync(), isFalse);
  });

  test('без отметки итога нет; испорченная отметка просто убирается', () async {
    final service = DesktopUpdateService.instance..debugCurrentBuild = 642;
    await service.settlePreviousAttempt();
    expect(service.lastAttempt.value, isNull);

    pending().writeAsStringSync('not json');
    await service.settlePreviousAttempt();
    expect(service.lastAttempt.value, isNull);
    expect(pending().existsSync(), isFalse);
  });

  test('подпись не сошлась — итог «проверка», отметки нет', () async {
    final r = await prepare(badSignature: true);

    await DesktopUpdateService.instance.install();

    expect(r.launched, isEmpty);
    expect(
      DesktopUpdateService.instance.lastAttempt.value!.failure,
      DesktopUpdateFailure.verification,
    );
    expect(pending().existsSync(), isFalse);
    expect(r.setup.existsSync(), isFalse);
  });

  test('скачать не вышло — итог «скачивание»', () async {
    await prepare();
    DesktopUpdateService.instance.debugDownloader =
        (url, length, onProgress) async => throw const HttpException('503');

    await DesktopUpdateService.instance.install();

    final attempt = DesktopUpdateService.instance.lastAttempt.value!;
    expect(attempt.failure, DesktopUpdateFailure.download);
    expect(attempt.version, '1.8.63');
  });

  test('установщик не запустился — итог «запуск», отметка снята', () async {
    await prepare(launchFails: true);

    await DesktopUpdateService.instance.install();

    expect(
      DesktopUpdateService.instance.lastAttempt.value!.failure,
      DesktopUpdateFailure.launch,
    );
    expect(pending().existsSync(), isFalse);
    expect(
      DesktopUpdateService.instance.progress.value?.phase,
      DesktopUpdatePhase.failed,
    );
  });
}
