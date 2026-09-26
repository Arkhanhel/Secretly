// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// A и B (26.09.2026), привязка ПК с телефона.
//
// A: iPhone в строгом режиме отвечал «Contact is unverified» — ключ ПК нечем
// было проверить. Теперь ПК кладёт свой ключ в QR, телефон сверяет его с
// ключом на сервере: совпал — устройство проверено, не совпал — отказ, пакет
// с секретами профиля не уходит. Старый ПК без ключа в строгом режиме —
// понятный отказ ДО сборки пакета.
//
// B: «синхронизировать медиа» складывало всю медиатеку в память — «Out of
// memory». Теперь бюджет: сначала новые, всего 48 МБ, файл больше 12 МБ
// пропускается, и всё под потолком вложения вместе со снимком базы.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/app/desktop_link_flow.dart';

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

String _controllerSource() =>
    File('lib/app/app_controller.dart').readAsStringSync();

/// Тело метода от сигнатуры до следующего метода того же отступа.
String _methodBody(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, greaterThanOrEqualTo(0), reason: 'нет «$signature»');
  final end = source.indexOf(RegExp(r'\n  \}\n'), start);
  expect(end, greaterThan(start));
  return source.substring(start, end);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 32 байта с «+», «/» и «=» в base64 — всё, что может сломать разбор QR.
  final keyA = base64Encode(List<int>.generate(32, (i) => (i * 37 + 251) & 0xff));
  final keyB = base64Encode(List<int>.generate(32, (i) => (i * 11 + 3) & 0xff));

  group('A: ключ ПК в QR', () {
    test('ключ доезжает через QR без искажений', () {
      expect(keyA, contains('='));
      final request = DesktopLinkRequest(
        requestId: 'req-a',
        targetProfileId: 'profile-a',
        targetDeviceId: 'device-a',
        requestNonce: 'nonce-a',
        deviceLabel: 'Mac',
        createdAtMs: 1,
        expiresAtMs: 9999999999999,
        status: 'pending',
        identityKeyB64: keyA,
      );
      final raw = AppController().buildDesktopLinkQrPayload(request);
      expect(raw, contains('identity_key=$keyA'));
      final parsed = DesktopLinkQrPayload.tryParse(raw);
      expect(parsed, isNotNull);
      expect(parsed!.identityKeyB64, keyA);
    });

    test('без ключа строки нет, а разбор даёт пусто (старый ПК)', () {
      const request = DesktopLinkRequest(
        requestId: 'req-b',
        targetProfileId: 'profile-b',
        targetDeviceId: 'device-b',
        requestNonce: 'nonce-b',
        deviceLabel: 'Mac',
        createdAtMs: 1,
        expiresAtMs: 9999999999999,
        status: 'pending',
      );
      final raw = AppController().buildDesktopLinkQrPayload(request);
      expect(raw, isNot(contains('identity_key=')));
      expect(DesktopLinkQrPayload.tryParse(raw)!.identityKeyB64, isEmpty);
    });

    test('ключ переживает сохранение запроса; старая запись — пусто', () {
      final request = DesktopLinkRequest(
        requestId: 'req-c',
        targetProfileId: 'profile-c',
        targetDeviceId: 'device-c',
        requestNonce: 'nonce-c',
        deviceLabel: 'Mac',
        createdAtMs: 1,
        expiresAtMs: 2,
        status: 'pending',
        identityKeyB64: keyA,
      );
      final json = request.toJson();
      expect(DesktopLinkRequest.fromJson(json)!.identityKeyB64, keyA);
      json.remove('identity_key_b64');
      expect(DesktopLinkRequest.fromJson(json)!.identityKeyB64, isEmpty);
    });

    test('сверка ключей: совпал / не совпал / нет в QR / нет на сервере', () {
      expect(
        checkDesktopLinkIdentity(qrKeyB64: keyA, serverKeyB64: keyA),
        DesktopLinkIdentityCheck.verified,
      );
      expect(
        checkDesktopLinkIdentity(qrKeyB64: keyA, serverKeyB64: keyB),
        DesktopLinkIdentityCheck.mismatch,
      );
      expect(
        checkDesktopLinkIdentity(
          qrKeyB64: keyA,
          serverKeyB64: base64Encode(List<int>.filled(33, 7)),
        ),
        DesktopLinkIdentityCheck.mismatch,
      );
      expect(
        checkDesktopLinkIdentity(qrKeyB64: '%%%не base64', serverKeyB64: keyA),
        DesktopLinkIdentityCheck.mismatch,
      );
      expect(
        checkDesktopLinkIdentity(qrKeyB64: '', serverKeyB64: keyA),
        DesktopLinkIdentityCheck.notProvided,
      );
      expect(
        checkDesktopLinkIdentity(qrKeyB64: '', serverKeyB64: null),
        DesktopLinkIdentityCheck.notProvided,
      );
      expect(
        checkDesktopLinkIdentity(qrKeyB64: keyA, serverKeyB64: null),
        DesktopLinkIdentityCheck.serverKeyMissing,
      );
      expect(
        checkDesktopLinkIdentity(qrKeyB64: keyA, serverKeyB64: '  '),
        DesktopLinkIdentityCheck.serverKeyMissing,
      );
    });

    test('новые отказы названы по-человечески', () {
      for (final code in [
        DesktopLinkFailureCode.desktopIdentityMismatch,
        DesktopLinkFailureCode.strictModeNeedsVerifiedDesktop,
      ]) {
        expect(DesktopLinkFailure(code).message, isNotEmpty);
      }
    });

    test('сверка стоит ДО сборки пакета, и её исход решает', () {
      final src = _controllerSource();
      final approve = _methodBody(
        src,
        'Future<void> approveDesktopLinkFromQr({',
      );
      final verifyAt = approve.indexOf(
        'await _verifyDesktopLinkTargetIdentity(payload);',
      );
      expect(verifyAt, greaterThan(0));
      expect(verifyAt, lessThan(approve.indexOf("'collect_backup_start'")));
      expect(verifyAt, lessThan(approve.indexOf('_collectSafeBackupPlain(')));
      expect(verifyAt, lessThan(approve.indexOf('_sendDesktopLinkAttachment')));

      final verify = _methodBody(
        src,
        'Future<void> _verifyDesktopLinkTargetIdentity(',
      );
      // Совпал — отметка на ТОМ устройстве, что в QR.
      expect(
        verify,
        matches(
          RegExp(
            r'DesktopLinkIdentityCheck\.verified:\s*await _db\?\.contactDeviceMarkVerified\(\s*profileId: targetProfileId,\s*deviceId: targetDeviceId,',
          ),
        ),
      );
      // Не совпал — отказ в ЛЮБОМ режиме.
      expect(
        verify,
        matches(
          RegExp(
            r'DesktopLinkIdentityCheck\.mismatch:\s*throw DesktopLinkFailure\(\s*DesktopLinkFailureCode\.desktopIdentityMismatch',
          ),
        ),
      );
      // Нечем проверить — отказ только в строгом режиме.
      expect(
        verify,
        matches(
          RegExp(
            r'DesktopLinkIdentityCheck\.serverKeyMissing:\s*if \(_blockUnverified\) \{\s*throw DesktopLinkFailure\(\s*DesktopLinkFailureCode\.strictModeNeedsVerifiedDesktop',
          ),
        ),
      );
    });
  });

  group('B: бюджет медиа', () {
    test('берёт в пределах, пропускает крупное и переполнение', () {
      final b = DesktopLinkMediaBudget(maxTotalBytes: 100, maxFileBytes: 60);
      expect(b.admit(50), isTrue);
      expect(b.admit(61), isFalse, reason: 'файл крупнее предела');
      expect(b.admit(51), isFalse, reason: 'не лезет в остаток');
      expect(b.admit(50), isTrue, reason: 'а этот влезает ровно');
      expect(b.usedBytes, 100);
      expect(b.included, 2);
      expect(b.skipped, 2);
      expect(b.skippedBytes, 112);
    });

    test('по умолчанию 48 МБ всего и 12 МБ на файл', () {
      final b = DesktopLinkMediaBudget();
      expect(b.maxTotalBytes, 48 * 1024 * 1024);
      expect(b.maxFileBytes, 12 * 1024 * 1024);
    });

    test('сжимается до остатка под потолком вложения', () {
      const mib = 1024 * 1024;
      final roomy = DesktopLinkMediaBudget()
        ..fitUnderAttachmentCeiling(
          attachmentCeilingBytes: 100 * mib,
          otherPayloadBytes: 10 * mib,
        );
      expect(roomy.maxTotalBytes, 48 * mib, reason: 'места хватает');

      final tight = DesktopLinkMediaBudget()
        ..fitUnderAttachmentCeiling(
          attachmentCeilingBytes: 100 * mib,
          otherPayloadBytes: 60 * mib,
        );
      // (100 − 60 − 2) МиБ места, base64 раздувает на треть.
      expect(tight.maxTotalBytes, 38 * mib * 3 ~/ 4);
      // Медиа в base64 + остальное — под потолком.
      expect(
        tight.maxTotalBytes * 4 ~/ 3 + 60 * mib,
        lessThanOrEqualTo(100 * mib),
      );

      final none = DesktopLinkMediaBudget()
        ..fitUnderAttachmentCeiling(
          attachmentCeilingBytes: 100 * mib,
          otherPayloadBytes: 120 * mib,
        );
      expect(none.maxTotalBytes, 0);
      expect(none.admit(1), isFalse);
    });

    test('длина JSON считается точно, и для кириллицы тоже', () {
      final value = <String, Object?>{
        'messages': [
          {'body': 'Привет, как дела? 👋', 'ts': 1790350089558},
          {'body': 'ok', 'ts': null, 'flag': true},
        ],
      };
      expect(
        desktopLinkJsonUtf8Length(value),
        utf8.encode(jsonEncode(value)).length,
      );
    });

    group('на диске', () {
      late Directory docs;

      setUp(() async {
        docs = await Directory.systemTemp.createTemp('secretly-b-budget-');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              _pathProviderChannel,
              (call) async => docs.path,
            );
        Future<void> put(String rel, int size, DateTime mtime) async {
          final f = File('${docs.path}/$rel');
          await f.parent.create(recursive: true);
          await f.writeAsBytes(List<int>.filled(size, 1));
          await f.setLastModified(mtime);
        }

        // Имена так, чтобы по алфавиту первым шло СТАРОЕ: порядок задаёт
        // сортировка по времени, а не выдача каталога.
        await put('attachments/a_old.bin', 600, DateTime(2025, 1, 1));
        await put('attachments/m_huge.bin', 1200, DateTime(2026, 6, 1));
        await put('attachments/z_new.bin', 600, DateTime(2026, 9, 1));
        await put('stickers/pack/s1.webp', 100, DateTime(2024, 1, 1));
      });

      tearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_pathProviderChannel, null);
        if (await docs.exists()) await docs.delete(recursive: true);
      });

      test('с бюджетом: стикеры, затем новое; старое и крупное — нет', () async {
        final budget = DesktopLinkMediaBudget(
          maxTotalBytes: 1200,
          maxFileBytes: 1000,
        );
        final out = await AppController().collectSafeBackupBinaryFilesForTest(
          budget: budget,
        );
        expect(
          out.keys.toSet(),
          {'stickers/pack/s1.webp', 'attachments/z_new.bin'},
        );
        expect(budget.included, 2);
        expect(budget.skipped, 2);
        expect(budget.usedBytes, 700);
      });

      test('без бюджета — всё, как раньше (обычная копия)', () async {
        final out = await AppController().collectSafeBackupBinaryFilesForTest();
        expect(out.keys.toSet(), {
          'attachments/a_old.bin',
          'attachments/m_huge.bin',
          'attachments/z_new.bin',
          'stickers/pack/s1.webp',
        });
      });
    });

    test('бюджет — только у привязки ПК; размер до чтения байтов', () {
      final src = _controllerSource();
      final approve = _methodBody(
        src,
        'Future<void> approveDesktopLinkFromQr({',
      );
      expect(
        approve,
        matches(
          RegExp(
            r'final mediaBudget = \(syncChats && syncMedia\)\s*\? DesktopLinkMediaBudget\(\)\s*: null;',
          ),
        ),
      );
      expect(approve, contains('mediaBudget: mediaBudget,'));
      // Остальные копии (сервер, файл) бюджета не получают.
      expect('mediaBudget:'.allMatches(src).length, 1);

      final addFile = _methodBody(
        src,
        'Future<void> _safeBackupAddFileIfExists({',
      );
      final admitAt = addFile.indexOf('budget.admit(await f.length())');
      expect(admitAt, greaterThan(0));
      expect(admitAt, lessThan(addFile.indexOf('readAsBytes()')));
    });
  });
}
