// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ЗАЩИТА ОТ ОТКАТА ПРИ ОБНОВЛЕНИИ НА WINDOWS (01.10.2026).
//
// 🔴 Подписью EdDSA заверены только байты установщика, а номер сборки брался
// из перечня версий, который не подписан. Подменённый перечень мог подсунуть
// наш же честно подписанный, но СТАРЫЙ установщик. Теперь номер читается из
// ресурса версии самого файла (заверенные байты), и запускается только
// строго более новая сборка; нет ресурса версии — отказ.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_update_service.dart';
import 'package:secretly_app/ui/desktop/services/pe_version.dart';

import 'support/synthetic_pe.dart';

const _url =
    'https://updates.secretlyapp.com/Secretly-Setup-1.8.63-700-x64.exe';

void main() {
  group('разбор ресурса версии PE', () {
    test('PE32+ — номер сборки из FILEVERSION', () {
      final v = parsePeFileVersion(
        buildSyntheticPe(major: 1, minor: 8, patch: 63, build: 700),
      )!;
      expect('$v', '1.8.63.700');
      expect(v.build, 700);
    });

    test('PE32 — тоже', () {
      final v = parsePeFileVersion(
        buildSyntheticPe(major: 2, minor: 0, patch: 1, build: 65535, pe32: true),
      )!;
      expect([v.major, v.minor, v.patch, v.build], [2, 0, 1, 65535]);
    });

    test('🔴 нет ресурса версии, чужая подпись структуры, не PE — null', () {
      expect(
        parsePeFileVersion(buildSyntheticPe(
          major: 1, minor: 8, patch: 63, build: 700, withVersion: false,
        )),
        isNull,
      );
      expect(
        parsePeFileVersion(buildSyntheticPe(
          major: 1, minor: 8, patch: 63, build: 700, fixedSignature: 0x12345678,
        )),
        isNull,
      );
      expect(
        parsePeFileVersion(Uint8List.fromList(utf8.encode('MZ fake installer'))),
        isNull,
      );
      expect(parsePeFileVersion(Uint8List(0)), isNull);
      final good = buildSyntheticPe(major: 1, minor: 8, patch: 63, build: 700);
      for (final cut in [0x40, 0x100, 0x210, good.length - 10]) {
        expect(
          parsePeFileVersion(Uint8List.sublistView(good, 0, cut)),
          isNull,
          reason: 'обрезано до $cut',
        );
      }
    });

    test('установщик и правда несёт номер сборки в ресурсе версии', () {
      final iss = File('windows/installer/secretly.iss').readAsStringSync();
      expect(iss, contains('VersionInfoVersion={#AppVersion}.{#AppBuild}'));
    });
  });

  group('запуск только строго более новой сборки', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('secretly-downgrade');
      DesktopUpdateService.debugDownloadDir = tmp;
    });

    tearDown(() {
      DesktopUpdateService.instance.debugReset();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    Future<List<String>> attempt({
      required Uint8List bytes,
      required int running,
      int feedBuild = 700,
    }) async {
      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPair();
      final signature = await algorithm.sign(bytes, keyPair: keyPair);
      final publicKey = await keyPair.extractPublicKey();
      final setup = File('${tmp.path}/Secretly-Setup.exe');
      final launched = <String>[];
      final service = DesktopUpdateService.instance
        ..debugWindowsPath = true
        ..debugCurrentBuild = running
        ..debugPublicKeyB64 = base64Encode(publicKey.bytes)
        ..debugDownloader = (url, length, onProgress) async {
          setup.writeAsBytesSync(bytes);
          return setup;
        }
        ..debugLauncher = (path, args) async {
          launched.add(path);
        }
        ..debugQuit = () async {};
      service.available.value = DesktopUpdateOffer(
        version: '1.8.63',
        // Перечень не подписан — он может врать про номер.
        build: feedBuild,
        downloadUrl: _url,
        edSignature: base64Encode(signature.bytes),
        length: bytes.length,
      );
      await service.install();
      return launched;
    }

    test('новее — запускается, в отметку идёт номер из файла', () async {
      final launched = await attempt(
        bytes: buildSyntheticPe(
          major: 1, minor: 8, patch: 63, build: 700, padding: 1000,
        ),
        running: 642,
        feedBuild: 999,
      );
      expect(launched, hasLength(1));
      final marker = jsonDecode(
        File('${tmp.path}/pending-update.json').readAsStringSync(),
      );
      expect(marker['build'], 700, reason: 'заверенный номер, не из перечня');
    });

    test('🔴 перечень врёт «999», а файл — старая сборка: НЕ запускается',
        () async {
      final launched = await attempt(
        bytes: buildSyntheticPe(
          major: 1, minor: 8, patch: 55, build: 610, padding: 1000,
        ),
        running: 642,
        feedBuild: 999,
      );
      expect(launched, isEmpty);
      final service = DesktopUpdateService.instance;
      expect(service.lastAttempt.value!.failure,
          DesktopUpdateFailure.verification);
      expect(File('${tmp.path}/Secretly-Setup.exe').existsSync(), isFalse,
          reason: 'отвергнутый файл удалён');
      expect(File('${tmp.path}/pending-update.json').existsSync(), isFalse);
    });

    test('🔴 та же сборка — тоже нет: только строго новее', () async {
      final launched = await attempt(
        bytes: buildSyntheticPe(
          major: 1, minor: 8, patch: 63, build: 642, padding: 1000,
        ),
        running: 642,
      );
      expect(launched, isEmpty);
    });

    test('🔴 нет ресурса версии — отказ, а не «наверное, можно»', () async {
      final launched = await attempt(
        bytes: buildSyntheticPe(
          major: 1, minor: 8, patch: 63, build: 700,
          withVersion: false, padding: 1000,
        ),
        running: 642,
      );
      expect(launched, isEmpty);
      expect(DesktopUpdateService.instance.lastAttempt.value!.failure,
          DesktopUpdateFailure.verification);
    });
  });
}
